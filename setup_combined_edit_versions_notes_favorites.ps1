# PromptVault - Combined Step (Edit + Versions + Notes + Favorites)
# Run this from inside your promptvault project folder, with (venv) active.
# Writes all files needed for these 4 features, then runs migrations automatically.

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
    is_favorite = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title


class PromptVersion(models.Model):
    prompt = models.ForeignKey(Prompt, on_delete=models.CASCADE, related_name='versions')
    title = models.CharField(max_length=200)
    text = models.TextField()
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True)
    saved_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-saved_at']

    def __str__(self):
        return "%s (version saved %s)" % (self.title, self.saved_at)


class Note(models.Model):
    prompt = models.ForeignKey(Prompt, on_delete=models.CASCADE, related_name='notes')
    text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return "Note on %s" % self.prompt.title
'@ | Set-Content -Path ".\prompts\models.py" -Encoding utf8

Write-Host "Writing prompts/admin.py ..." -ForegroundColor Cyan
@'
from django.contrib import admin
from .models import Prompt, Category, PromptVersion, Note

admin.site.register(Prompt)
admin.site.register(Category)
admin.site.register(PromptVersion)
admin.site.register(Note)
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
'@ | Set-Content -Path ".\prompts\views.py" -Encoding utf8

Write-Host "Writing prompts/urls.py ..." -ForegroundColor Cyan
@'
from django.urls import path
from . import views

urlpatterns = [
    path('', views.prompt_list, name='prompt_list'),
    path('add/', views.prompt_add, name='prompt_add'),
    path('<int:pk>/', views.prompt_detail, name='prompt_detail'),
    path('<int:pk>/edit/', views.prompt_edit, name='prompt_edit'),
    path('<int:pk>/versions/', views.prompt_versions, name='prompt_versions'),
    path('<int:pk>/favorite/', views.prompt_favorite_toggle, name='prompt_favorite_toggle'),
]
'@ | Set-Content -Path ".\prompts\urls.py" -Encoding utf8

Write-Host "Writing prompts/templates/prompts/prompt_list.html ..." -ForegroundColor Cyan
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
    .filterbar { margin-bottom: 16px; display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
    select, input[type=text] { padding: 6px; }
    .tag { display: inline-block; background: #eef2ff; color: #3730a3; padding: 2px 8px; border-radius: 10px; font-size: 12px; margin-left: 8px; }
    button { padding: 6px 14px; background: #2563eb; color: white; border: none; border-radius: 4px; cursor: pointer; }
    .star { color: #f59e0b; }
  </style>
</head>
<body>
  <div class="topbar">
    <h1>My Prompts</h1>
    <a href="{% url 'logout' %}">Log out</a>
  </div>

  <p><a href="{% url 'prompt_add' %}">+ Add New Prompt</a></p>

  <form method="get" class="filterbar">
    <input type="text" name="q" placeholder="Search title or text..." value="{{ search_query }}">
    <select name="category" onchange="this.form.submit()">
      <option value="">All categories</option>
      {% for cat in categories %}
        <option value="{{ cat.id }}" {% if selected_category == cat.id|stringformat:"s" %}selected{% endif %}>{{ cat.name }}</option>
      {% endfor %}
    </select>
    <label>
      <input type="checkbox" name="favorites" value="1" {% if favorites_only %}checked{% endif %} onchange="this.form.submit()">
      Favorites only
    </label>
    <button type="submit">Search</button>
    <a href="{% url 'prompt_list' %}">Clear</a>
  </form>

  <ul>
    {% for prompt in prompts %}
      <li>
        {% if prompt.is_favorite %}<span class="star">*</span>{% endif %}
        <a href="{% url 'prompt_detail' prompt.pk %}">{{ prompt.title }}</a>
        {% if prompt.category %}<span class="tag">{{ prompt.category.name }}</span>{% endif %}
        - <small>{{ prompt.created_at|date:"M d, Y" }}</small>
      </li>
    {% empty %}
      <li>No prompts found.</li>
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
    a { color: #2563eb; text-decoration: none; display: inline-block; margin-top: 12px; margin-right: 16px; }
    .tag { display: inline-block; background: #eef2ff; color: #3730a3; padding: 2px 8px; border-radius: 10px; font-size: 12px; }
    .star { color: #f59e0b; font-size: 20px; }
    .notes { margin-top: 24px; background: #fafafa; padding: 16px; border-radius: 6px; }
    .note { padding: 8px 0; border-bottom: 1px solid #eee; }
    textarea { width: 100%; height: 70px; padding: 8px; box-sizing: border-box; }
    button { padding: 6px 14px; background: #2563eb; color: white; border: none; border-radius: 4px; cursor: pointer; margin-top: 8px; }
  </style>
</head>
<body>
  <h1>
    {{ prompt.title }}
    <a href="{% url 'prompt_favorite_toggle' prompt.pk %}" class="star" title="Toggle favorite">
      {% if prompt.is_favorite %}[Favorited - click to unfavorite]{% else %}[Click to favorite]{% endif %}
    </a>
  </h1>
  {% if prompt.category %}<p class="tag">{{ prompt.category.name }}</p>{% endif %}
  <pre>{{ prompt.text }}</pre>
  <p><small>Created: {{ prompt.created_at }} | Updated: {{ prompt.updated_at }}</small></p>

  <a href="{% url 'prompt_edit' prompt.pk %}">Edit this prompt</a>
  <a href="{% url 'prompt_versions' prompt.pk %}">View version history</a>
  <a href="{% url 'prompt_list' %}">Back to list</a>

  <div class="notes">
    <h3>Notes</h3>
    {% for note in notes %}
      <div class="note">
        <p>{{ note.text }}</p>
        <small>{{ note.created_at }}</small>
      </div>
    {% empty %}
      <p>No notes yet.</p>
    {% endfor %}

    <form method="post">
      {% csrf_token %}
      <textarea name="note_text" placeholder="Add a note..."></textarea>
      <br>
      <button type="submit">Add Note</button>
    </form>
  </div>
</body>
</html>
'@ | Set-Content -Path ".\prompts\templates\prompts\prompt_detail.html" -Encoding utf8

Write-Host "Writing prompts/templates/prompts/prompt_form.html ..." -ForegroundColor Cyan
@'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>{% if editing %}Edit Prompt{% else %}Add Prompt{% endif %}</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 700px; margin: 40px auto; padding: 0 20px; }
    input[type=text], textarea, select { width: 100%; padding: 8px; margin: 6px 0 16px; box-sizing: border-box; }
    textarea { height: 150px; }
    button { background: #2563eb; color: white; border: none; padding: 10px 18px; border-radius: 4px; cursor: pointer; }
    a { color: #2563eb; text-decoration: none; display: inline-block; margin-top: 12px; }
  </style>
</head>
<body>
  <h1>{% if editing %}Edit Prompt{% else %}Add Prompt{% endif %}</h1>
  <form method="post">
    {% csrf_token %}
    {{ form.as_p }}
    <button type="submit">Save</button>
  </form>
  <a href="{% url 'prompt_list' %}">Back to list</a>
</body>
</html>
'@ | Set-Content -Path ".\prompts\templates\prompts\prompt_form.html" -Encoding utf8

Write-Host "Writing prompts/templates/prompts/prompt_versions.html ..." -ForegroundColor Cyan
@'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Version History - {{ prompt.title }}</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 700px; margin: 40px auto; padding: 0 20px; }
    pre { white-space: pre-wrap; background: #f5f5f5; padding: 16px; border-radius: 6px; }
    a { color: #2563eb; text-decoration: none; display: inline-block; margin-top: 12px; }
    .version { border: 1px solid #eee; border-radius: 6px; padding: 12px; margin-bottom: 12px; }
  </style>
</head>
<body>
  <h1>Version History</h1>
  <p>Current title: <strong>{{ prompt.title }}</strong></p>

  {% for version in versions %}
    <div class="version">
      <p><strong>{{ version.title }}</strong> - saved {{ version.saved_at }}</p>
      <pre>{{ version.text }}</pre>
    </div>
  {% empty %}
    <p>No past versions yet. Versions appear here after you edit this prompt at least once.</p>
  {% endfor %}

  <a href="{% url 'prompt_detail' prompt.pk %}">Back to prompt</a>
</body>
</html>
'@ | Set-Content -Path ".\prompts\templates\prompts\prompt_versions.html" -Encoding utf8

Write-Host ""
Write-Host "All files written successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Now running makemigrations and migrate automatically..." -ForegroundColor Cyan

py manage.py makemigrations
py manage.py migrate

Write-Host ""
Write-Host "Done. Now run: py manage.py runserver" -ForegroundColor Green
Write-Host "Then open a prompt and try: editing it, viewing version history, adding a note, and toggling favorite." -ForegroundColor Green
