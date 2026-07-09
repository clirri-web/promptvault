from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.db.models import Q
from .models import Prompt, Category, PromptVersion, Note
from .forms import PromptForm


@login_required
def prompt_list(request):
    prompts = Prompt.objects.filter(owner=request.user)

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

    prompts = prompts.order_by('-is_favorite', '-created_at')

    categories = Category.objects.all()

    return render(request, 'prompts/prompt_list.html', {
        'prompts': prompts,
        'categories': categories,
        'selected_category': category_id,
        'search_query': search_query,
        'favorites_only': favorites_only,
    })


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


@login_required
def prompt_detail(request, pk):
    prompt = get_object_or_404(Prompt, pk=pk, owner=request.user)
    notes = prompt.notes.all()

    if request.method == 'POST':
        note_text = request.POST.get('note_text', '').strip()
        if note_text:
            Note.objects.create(prompt=prompt, text=note_text)
        return redirect('prompt_detail', pk=prompt.pk)

    return render(request, 'prompts/prompt_detail.html', {'prompt': prompt, 'notes': notes})


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
