from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from .models import Prompt
from .forms import PromptForm


@login_required
def prompt_list(request):
    prompts = Prompt.objects.filter(owner=request.user).order_by('-created_at')
    return render(request, 'prompts/prompt_list.html', {'prompts': prompts})


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
    return render(request, 'prompts/prompt_detail.html', {'prompt': prompt})
