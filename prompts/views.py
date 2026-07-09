from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.db.models import Q, Count
from django.http import HttpResponseForbidden
from .models import Prompt, Category, PromptVersion, Note, Share
from .forms import PromptForm


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

    prompts = prompts.order_by('-is_pinned', '-is_favorite', '-created_at')

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
            return redirect('prompt_list')
    else:
        form = PromptForm()
    return render(request, 'prompts/prompt_form.html', {'form': form})


def _get_accessible_prompt(request, pk):
    prompt = get_object_or_404(Prompt, pk=pk)
    is_owner = prompt.owner_id == request.user.id
    has_access = is_owner or prompt.is_public or prompt.shares.filter(shared_with=request.user).exists()
    if not has_access:
        return None, None
    return prompt, is_owner


@login_required
def prompt_detail(request, pk):
    prompt, is_owner = _get_accessible_prompt(request, pk)
    if prompt is None:
        return HttpResponseForbidden("You do not have access to this prompt.")

    notes = prompt.notes.all()

    if request.method == 'POST':
        if not is_owner:
            return HttpResponseForbidden("Only the owner can add notes.")
        note_text = request.POST.get('note_text', '').strip()
        if note_text:
            Note.objects.create(prompt=prompt, text=note_text)
        return redirect('prompt_detail', pk=prompt.pk)

    return render(request, 'prompts/prompt_detail.html', {
        'prompt': prompt, 'notes': notes, 'is_owner': is_owner,
    })


@login_required
def prompt_edit(request, pk):
    prompt = get_object_or_404(Prompt, pk=pk, owner=request.user)
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
def prompt_versions(request, pk):
    prompt = get_object_or_404(Prompt, pk=pk, owner=request.user)
    versions = prompt.versions.all()
    return render(request, 'prompts/prompt_versions.html', {'prompt': prompt, 'versions': versions})


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
        owner=request.user,
    )
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
            try:
                target_user = User.objects.get(username=username)
                if target_user == request.user:
                    error = "You can't share a prompt with yourself."
                else:
                    Share.objects.get_or_create(prompt=prompt, shared_with=target_user)
            except User.DoesNotExist:
                error = "No user found with username '%s'." % username

        elif action == 'remove_user':
            share_id = request.POST.get('share_id')
            Share.objects.filter(id=share_id, prompt=prompt).delete()

        if not error:
            return redirect('prompt_share', pk=prompt.pk)

    shares = prompt.shares.select_related('shared_with')
    return render(request, 'prompts/prompt_share.html', {
        'prompt': prompt, 'shares': shares, 'error': error,
    })
