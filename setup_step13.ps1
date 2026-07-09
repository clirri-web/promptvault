# PromptVault - Step 13 (Categories) - Automated file writer
# Run this from inside your promptvault project folder, with (venv) active.
# It OVERWRITES the 4 files and 2 templates listed below with correct content.
# No manual copy-pasting needed - just run this script.

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\manage.py")) {
    Write-Host "ERROR: manage.py not found in this folder." -ForegroundColor Red
    Write-Host "Please 'cd' into your promptvault project folder first, then run this script again." -ForegroundColor Red
    exit 1
}

Write-Host "Writing prompts/models.py ..." -ForegroundColor Cyan
@'
from django.db import models
from django.contrib.auth.models import User


class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)

    class Meta:
        verbose_name_plural = "categories"
        ordering = ['name']

    def __str__(self):
        return self.name


class Prompt(models.Model):
    title = models.CharField(max_length=200)
    text = models.TextField()
    category = models.ForeignKey(
        Category, on_delete=models.SET_NULL, null=True, blank=True, related_name='prompts'
    )
    owner = models.ForeignKey(User, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title
'@ | Set-Content -Path ".\prompts\models.py" -Encoding utf8

Write-Host "Writing prompts/admin.py ..." -ForegroundColor Cyan
@'
from django.contrib import admin
from .models import Prompt, Category

admin.site.register(Prompt)
admin.site.register(Category)
'@ | Set-Content -Path ".\prompts\admin.py" -Encoding utf8

Write-Host "Writing prompts/forms.py ..." -ForegroundColor Cyan
@'
from django import forms
from .models import Prompt


class PromptForm(forms.ModelForm):
    class Meta:
        model = Prompt
        fields = ['title', 'text', 'category']
'@ | Set-Content -Path ".\prompts\forms.py" -Encoding utf8

Write-Host "Writing prompts/views.py ..." -ForegroundColor Cyan
@'
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from .models import Prompt, Category
from .forms import PromptForm


@login_required
def prompt_list(request):
    prompts = Prompt.objects.filter(owner=request.user).order_by('-created_at')

    category_id = request.GET.get('category')
    if category_id:
        prompts = prompts.filter(category_id=category_id)

    categories = Category.objects.all()

    return render(request, 'prompts/prompt_list.html', {
        'prompts': prompts,
        'categories': categories,
        'selected_category': category_id,
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
    return render(request, 'prompts/prompt_detail.html', {'prompt': prompt})
'@ | Set-Content -Path ".\prompts\views.py" -Encoding utf8

Write-Host "Writing prompts/templates/prompts/prompt_list.html ..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path ".\prompts\templates\prompts" | Out-Null
@'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>My Prompts</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 700px; margin: 40px auto; padding: 0 20px; }
    a { color: #2563eb; text-decoration: none; }
    a:hover { text-decoration: underline; }
    ul { list-style: none; padding: 0; }
    li { padding: 10px; border-bottom: 1px solid #eee; }
    .topbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
    .filterbar { margin-bottom: 16px; }
    select { padding: 6px; }
    .tag { display: inline-block; background: #eef2ff; color: #3730a3; padding: 2px 8px; border-radius: 10px; font-size: 12px; margin-left: 8px; }
  </style>
</head>
<body>
  <div class="topbar">
    <h1>My Prompts</h1>
    <a href="{% url 'logout' %}">Log out</a>
  </div>

  <p><a href="{% url 'prompt_add' %}">+ Add New Prompt</a></p>

  <form method="get" class="filterbar">
    <label for="category">Filter by category:</label>
    <select name="category" id="category" onchange="this.form.submit()">
      <option value="">All categories</option>
      {% for cat in categories %}
        <option value="{{ cat.id }}" {% if selected_category == cat.id|stringformat:"s" %}selected{% endif %}>{{ cat.name }}</option>
      {% endfor %}
    </select>
  </form>

  <ul>
    {% for prompt in prompts %}
      <li>
        <a href="{% url 'prompt_detail' prompt.pk %}">{{ prompt.title }}</a>
        {% if prompt.category %}<span class="tag">{{ prompt.category.name }}</span>{% endif %}
        — <small>{{ prompt.created_at|date:"M d, Y" }}</small>
      </li>
    {% empty %}
      <li>No prompts yet. Click "Add New Prompt" to create your first one.</li>
    {% endfor %}
  </ul>
</body>
</html>
'@ | Set-Content -Path ".\prompts\templates\prompts\prompt_list.html" -Encoding utf8

Write-Host "Writing prompts/templates/prompts/prompt_detail.html ..." -ForegroundColor Cyan
@'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>{{ prompt.title }}</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 700px; margin: 40px auto; padding: 0 20px; }
    pre { white-space: pre-wrap; background: #f5f5f5; padding: 16px; border-radius: 6px; }
    a { color: #2563eb; text-decoration: none; display: inline-block; margin-top: 12px; }
    .tag { display: inline-block; background: #eef2ff; color: #3730a3; padding: 2px 8px; border-radius: 10px; font-size: 12px; }
  </style>
</head>
<body>
  <h1>{{ prompt.title }}</h1>
  {% if prompt.category %}<p class="tag">{{ prompt.category.name }}</p>{% endif %}
  <pre>{{ prompt.text }}</pre>
  <p><small>Created: {{ prompt.created_at }} | Updated: {{ prompt.updated_at }}</small></p>
  <a href="{% url 'prompt_list' %}">← Back to list</a>
</body>
</html>
'@ | Set-Content -Path ".\prompts\templates\prompts\prompt_detail.html" -Encoding utf8

Write-Host ""
Write-Host "All files written successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Now running makemigrations and migrate automatically..." -ForegroundColor Cyan

py manage.py makemigrations
py manage.py migrate

Write-Host ""
Write-Host "Done. Now run: py manage.py runserver" -ForegroundColor Green
Write-Host "Then visit http://127.0.0.1:8000/admin/ to add a few categories," -ForegroundColor Green
Write-Host "and http://127.0.0.1:8000/prompts/ to see the filter dropdown." -ForegroundColor Green
