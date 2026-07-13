import json
import re

from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.db.models import Q, Count
from django.http import HttpResponseForbidden, JsonResponse
from .models import Prompt, Category, PromptVersion, Note, Share, Tag, Attachment
from .forms import PromptForm

MAX_ATTACHMENT_SIZE = 10 * 1024 * 1024  # 10 MB


@login_required
def dashboard(request):
    owned = Prompt.objects.filter(owner=request.user, is_archived=False)

    total_prompts = owned.count()
    favorites_count = owned.filter(is_favorite=True).count()
    categories_count = Category.objects.count()

    shared_with_me_count = Prompt.objects.filter(
        Q(is_public=True) | Q(shares__shared_with=request.user)
    ).exclude(owner=request.user).distinct().count()

    recent_prompts = owned.order_by('-created_at')[:5]
    favorite_prompts = owned.filter(is_favorite=True).order_by('-updated_at')[:5]

    category_breakdown = Category.objects.annotate(
        prompt_count=Count('prompts', filter=Q(prompts__owner=request.user, prompts__is_archived=False))
    ).order_by('-prompt_count')

    return render(request, 'prompts/dashboard.html', {
        'total_prompts': total_prompts,
        'favorites_count': favorites_count,
        'categories_count': categories_count,
        'shared_with_me_count': shared_with_me_count,
        'recent_prompts': recent_prompts,
        'favorite_prompts': favorite_prompts,
        'category_breakdown': category_breakdown,
    })


@login_required
def prompt_list(request):
    show_archived = request.GET.get('archived') == '1'
    prompts = Prompt.objects.filter(owner=request.user, is_archived=show_archived)

    category_id = request.GET.get('category')
    if category_id:
        prompts = prompts.filter(category_id=category_id)

    search_query = request.GET.get('q', '').strip()
    if search_query:
        prompts = prompts.filter(
            Q(title__icontains=search_query) | Q(text__icontains=search_query)
        )

    favorites_only = request.GET.get('favorites') == '1'
    if favorites_only:
        prompts = prompts.filter(is_favorite=True)

    prompts = prompts.order_by('-is_pinned', '-is_favorite', '-created_at').distinct()

    categories = Category.objects.all()

    return render(request, 'prompts/prompt_list.html', {
        'prompts': prompts,
        'categories': categories,
        'selected_category': category_id,
        'search_query': search_query,
        'favorites_only': favorites_only,
        'show_archived': show_archived,
    })


@login_required
def shared_list(request):
    prompts = Prompt.objects.filter(
        Q(is_public=True) | Q(shares__shared_with=request.user)
    ).exclude(owner=request.user).filter(is_archived=False).distinct().order_by('-created_at')

    return render(request, 'prompts/shared_list.html', {'prompts': prompts})


@login_required
def prompt_add(request):
    if request.method == 'POST':
        form = PromptForm(request.POST)
        if form.is_valid():
            prompt = form.save(commit=False)
            prompt.owner = request.user
            prompt.save()
            form.save_m2m()
            return redirect('prompt_list')
    else:
        form = PromptForm()
    return render(request, 'prompts/prompt_form.html', {'form': form})


def _get_accessible_prompt(request, pk):
    prompt = get_object_or_404(Prompt, pk=pk)
    is_owner = prompt.owner_id == request.user.id

    share = None
    if not is_owner:
        share = prompt.shares.filter(shared_with=request.user).first()

    has_access = is_owner or prompt.is_public or share is not None
    if not has_access:
        return None, None, None

    can_edit = is_owner or (share is not None and share.can_edit)
    return prompt, is_owner, can_edit


@login_required
def prompt_detail(request, pk):
    prompt, is_owner, can_edit = _get_accessible_prompt(request, pk)
    if prompt is None:
        return HttpResponseForbidden("You do not have access to this prompt.")

    notes = prompt.notes.all()
    attachments = prompt.attachments.all()

    if request.method == 'POST':
        if not can_edit:
            return HttpResponseForbidden("You do not have permission to add notes.")
        note_text = request.POST.get('note_text', '').strip()
        if note_text:
            Note.objects.create(prompt=prompt, text=note_text)
        return redirect('prompt_detail', pk=prompt.pk)

    return render(request, 'prompts/prompt_detail.html', {
        'prompt': prompt, 'notes': notes, 'attachments': attachments,
        'is_owner': is_owner, 'can_edit': can_edit,
    })


@login_required
def prompt_attachment_add(request, pk):
    prompt, is_owner, can_edit = _get_accessible_prompt(request, pk)
    if prompt is None or not can_edit:
        return HttpResponseForbidden("You do not have permission to add attachments.")

    if request.method == 'POST':
        uploaded_file = request.FILES.get('file')
        link = request.POST.get('link', '').strip()
        label = request.POST.get('label', '').strip()

        if uploaded_file and uploaded_file.size > MAX_ATTACHMENT_SIZE:
            return render(request, 'prompts/prompt_detail.html', {
                'prompt': prompt, 'notes': prompt.notes.all(), 'attachments': prompt.attachments.all(),
                'is_owner': is_owner, 'can_edit': can_edit,
                'attachment_error': "That file is too large. Maximum size is 10 MB.",
            })

        if uploaded_file or link:
            Attachment.objects.create(
                prompt=prompt, file=uploaded_file, link=link, label=label,
            )

    return redirect('prompt_detail', pk=prompt.pk)


@login_required
def prompt_attachment_delete(request, pk, attachment_id):
    prompt, is_owner, can_edit = _get_accessible_prompt(request, pk)
    if prompt is None or not can_edit:
        return HttpResponseForbidden("You do not have permission to remove attachments.")

    Attachment.objects.filter(id=attachment_id, prompt=prompt).delete()
    return redirect('prompt_detail', pk=prompt.pk)


@login_required
def prompt_edit(request, pk):
    prompt, is_owner, can_edit = _get_accessible_prompt(request, pk)
    if prompt is None or not can_edit:
        return HttpResponseForbidden("You do not have permission to edit this prompt.")

    if request.method == 'POST':
        form = PromptForm(request.POST, instance=prompt)
        if form.is_valid():
            PromptVersion.objects.create(
                prompt=prompt,
                title=prompt.title,
                text=prompt.text,
                category=prompt.category,
            )
            form.save()
            return redirect('prompt_detail', pk=prompt.pk)
    else:
        form = PromptForm(instance=prompt)
    return render(request, 'prompts/prompt_form.html', {'form': form, 'editing': True})


@login_required
def prompt_use_template(request, pk):
    prompt, is_owner, can_edit = _get_accessible_prompt(request, pk)
    if prompt is None:
        return HttpResponseForbidden("You do not have access to this prompt.")

    variables = sorted(set(re.findall(r'\{\{(\w+)\}\}', prompt.text)))
    filled_text = None

    if request.method == 'POST':
        filled_text = prompt.text
        for var in variables:
            value = request.POST.get(var, '')
            filled_text = filled_text.replace('{{%s}}' % var, value)

    return render(request, 'prompts/prompt_use_template.html', {
        'prompt': prompt, 'variables': variables, 'filled_text': filled_text,
    })


@login_required
def prompt_versions(request, pk):
    prompt = get_object_or_404(Prompt, pk=pk, owner=request.user)
    versions = prompt.versions.all()
    return render(request, 'prompts/prompt_versions.html', {'prompt': prompt, 'versions': versions})


@login_required
def prompt_version_restore(request, pk, version_id):
    prompt = get_object_or_404(Prompt, pk=pk, owner=request.user)
    version = get_object_or_404(PromptVersion, pk=version_id, prompt=prompt)

    PromptVersion.objects.create(
        prompt=prompt,
        title=prompt.title,
        text=prompt.text,
        category=prompt.category,
    )

    prompt.title = version.title
    prompt.text = version.text
    prompt.category = version.category
    prompt.save()

    return redirect('prompt_detail', pk=prompt.pk)


@login_required
def prompt_favorite_toggle(request, pk):
    prompt = get_object_or_404(Prompt, pk=pk, owner=request.user)
    prompt.is_favorite = not prompt.is_favorite
    prompt.save()
    return redirect('prompt_detail', pk=prompt.pk)


@login_required
def prompt_pin_toggle(request, pk):
    prompt = get_object_or_404(Prompt, pk=pk, owner=request.user)
    prompt.is_pinned = not prompt.is_pinned
    prompt.save()
    return redirect('prompt_detail', pk=prompt.pk)


@login_required
def prompt_archive_toggle(request, pk):
    prompt = get_object_or_404(Prompt, pk=pk, owner=request.user)
    prompt.is_archived = not prompt.is_archived
    prompt.save()
    return redirect('prompt_detail', pk=prompt.pk)


@login_required
def prompt_duplicate(request, pk):
    original = get_object_or_404(Prompt, pk=pk, owner=request.user)
    duplicate = Prompt.objects.create(
        title=original.title + " (copy)",
        text=original.text,
        category=original.category,
        ai_model=original.ai_model,
        rating=original.rating,
        is_template=original.is_template,
        owner=request.user,
    )
    duplicate.tags.set(original.tags.all())
    return redirect('prompt_detail', pk=duplicate.pk)


@login_required
def prompt_delete(request, pk):
    prompt = get_object_or_404(Prompt, pk=pk, owner=request.user)
    if request.method == 'POST':
        prompt.delete()
        return redirect('prompt_list')
    return render(request, 'prompts/prompt_delete_confirm.html', {'prompt': prompt})


@login_required
def prompt_share(request, pk):
    prompt = get_object_or_404(Prompt, pk=pk, owner=request.user)
    error = None

    if request.method == 'POST':
        action = request.POST.get('action')

        if action == 'toggle_public':
            prompt.is_public = not prompt.is_public
            prompt.save()

        elif action == 'add_user':
            username = request.POST.get('username', '').strip()
            can_edit = request.POST.get('can_edit') == 'on'
            try:
                target_user = User.objects.get(username=username)
                if target_user == request.user:
                    error = "You can't share a prompt with yourself."
                else:
                    share, _ = Share.objects.get_or_create(prompt=prompt, shared_with=target_user)
                    share.can_edit = can_edit
                    share.save()
            except User.DoesNotExist:
                error = "No user found with username '%s'." % username

        elif action == 'remove_user':
            share_id = request.POST.get('share_id')
            Share.objects.filter(id=share_id, prompt=prompt).delete()

        elif action == 'toggle_edit':
            share_id = request.POST.get('share_id')
            share_obj = Share.objects.filter(id=share_id, prompt=prompt).first()
            if share_obj:
                share_obj.can_edit = not share_obj.can_edit
                share_obj.save()

        if not error:
            return redirect('prompt_share', pk=prompt.pk)

    shares = prompt.shares.select_related('shared_with')
    return render(request, 'prompts/prompt_share.html', {
        'prompt': prompt, 'shares': shares, 'error': error,
    })


@login_required
def settings_page(request):
    return render(request, 'prompts/settings.html', {})


@login_required
def export_prompts(request):
    prompts = Prompt.objects.filter(owner=request.user)
    data = []
    for p in prompts:
        data.append({
            'title': p.title,
            'text': p.text,
            'category': p.category.name if p.category else None,
            'tags': [t.name for t in p.tags.all()],
            'ai_model': p.ai_model,
            'rating': p.rating,
            'is_favorite': p.is_favorite,
            'is_template': p.is_template,
        })
    response = JsonResponse(data, safe=False, json_dumps_params={'indent': 2})
    response['Content-Disposition'] = 'attachment; filename="promptvault_export.json"'
    return response


@login_required
def import_prompts(request):
    message = None
    if request.method == 'POST' and request.FILES.get('import_file'):
        try:
            data = json.load(request.FILES['import_file'])
            count = 0
            for item in data:
                category = None
                if item.get('category'):
                    category, _ = Category.objects.get_or_create(name=item['category'])

                prompt = Prompt.objects.create(
                    title=item.get('title', 'Untitled'),
                    text=item.get('text', ''),
                    category=category,
                    owner=request.user,
                    ai_model=item.get('ai_model', ''),
                    rating=item.get('rating', 0),
                    is_favorite=item.get('is_favorite', False),
                    is_template=item.get('is_template', False),
                )
                for tag_name in item.get('tags', []):
                    tag, _ = Tag.objects.get_or_create(name=tag_name)
                    prompt.tags.add(tag)
                count += 1
            message = "Imported %d prompt(s) successfully." % count
        except Exception as e:
            message = "Import failed: %s" % e

    return render(request, 'prompts/import_prompts.html', {'message': message})
