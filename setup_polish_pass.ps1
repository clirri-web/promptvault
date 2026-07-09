# PromptVault - Polish Pass (Bootstrap styling, nav bar, Delete feature)
# Run this from inside your promptvault project folder, with (venv) active.

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\manage.py")) {
    Write-Host "ERROR: manage.py not found in this folder." -ForegroundColor Red
    Write-Host "Please 'cd' into your promptvault project folder first, then run this script again." -ForegroundColor Red
    exit 1
}

Write-Host "Creating templates/base.html ..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path ".\templates" | Out-Null
@'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>{% block title %}PromptVault{% endblock %}</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  <style>
    body { background-color: #f8f9fa; }
    .navbar-brand { font-weight: 600; }
    .tag { font-size: 12px; }
    pre.prompt-text { white-space: pre-wrap; background: #f1f3f5; padding: 16px; border-radius: 8px; }
    .star-btn { text-decoration: none; font-size: 1.3rem; }
  </style>
</head>
<body>
  <nav class="navbar navbar-expand-lg navbar-dark bg-dark mb-4">
    <div class="container">
      <a class="navbar-brand" href="{% url 'prompt_list' %}">PromptVault</a>
      {% if user.is_authenticated %}
        <div class="d-flex">
          <a class="btn btn-outline-light btn-sm me-2" href="{% url 'prompt_add' %}">+ Add Prompt</a>
          <a class="btn btn-outline-light btn-sm" href="{% url 'logout' %}">Log out</a>
        </div>
      {% endif %}
    </div>
  </nav>

  <div class="container">
    {% block content %}{% endblock %}
  </div>
</body>
</html>
'@ | Set-Content -Path ".\templates\base.html" -Encoding utf8

Write-Host "Writing prompts/templates/prompts/prompt_list.html ..." -ForegroundColor Cyan
@'
{% extends "base.html" %}
{% block title %}My Prompts{% endblock %}
{% block content %}

<h1 class="mb-4">My Prompts</h1>

<form method="get" class="row g-2 align-items-center mb-4">
  <div class="col-auto">
    <input type="text" name="q" class="form-control" placeholder="Search title or text..." value="{{ search_query }}">
  </div>
  <div class="col-auto">
    <select name="category" class="form-select" onchange="this.form.submit()">
      <option value="">All categories</option>
      {% for cat in categories %}
        <option value="{{ cat.id }}" {% if selected_category == cat.id|stringformat:"s" %}selected{% endif %}>{{ cat.name }}</option>
      {% endfor %}
    </select>
  </div>
  <div class="col-auto form-check">
    <input type="checkbox" class="form-check-input" name="favorites" value="1" id="favCheck" {% if favorites_only %}checked{% endif %} onchange="this.form.submit()">
    <label class="form-check-label" for="favCheck">Favorites only</label>
  </div>
  <div class="col-auto">
    <button type="submit" class="btn btn-primary">Search</button>
    <a href="{% url 'prompt_list' %}" class="btn btn-outline-secondary">Clear</a>
  </div>
</form>

<div class="list-group">
  {% for prompt in prompts %}
    <div class="list-group-item d-flex justify-content-between align-items-center">
      <div>
        {% if prompt.is_favorite %}<span class="text-warning">&#9733;</span>{% endif %}
        <a href="{% url 'prompt_detail' prompt.pk %}" class="fw-semibold text-decoration-none">{{ prompt.title }}</a>
        {% if prompt.category %}<span class="badge bg-light text-dark tag ms-2">{{ prompt.category.name }}</span>{% endif %}
        <small class="text-muted ms-2">{{ prompt.created_at|date:"M d, Y" }}</small>
      </div>
    </div>
  {% empty %}
    <div class="list-group-item">No prompts found.</div>
  {% endfor %}
</div>

{% endblock %}
'@ | Set-Content -Path ".\prompts\templates\prompts\prompt_list.html" -Encoding utf8

Write-Host "Writing prompts/templates/prompts/prompt_detail.html ..." -ForegroundColor Cyan
@'
{% extends "base.html" %}
{% block title %}{{ prompt.title }}{% endblock %}
{% block content %}

<div class="d-flex justify-content-between align-items-start">
  <h1>
    {{ prompt.title }}
    <a href="{% url 'prompt_favorite_toggle' prompt.pk %}" class="star-btn" title="Toggle favorite">
      {% if prompt.is_favorite %}&#9733;{% else %}&#9734;{% endif %}
    </a>
  </h1>
</div>

{% if prompt.category %}<span class="badge bg-light text-dark tag mb-2">{{ prompt.category.name }}</span>{% endif %}

<pre class="prompt-text">{{ prompt.text }}</pre>

<p class="text-muted"><small>Created: {{ prompt.created_at }} | Updated: {{ prompt.updated_at }}</small></p>

<div class="mb-4">
  <a href="{% url 'prompt_edit' prompt.pk %}" class="btn btn-primary btn-sm">Edit</a>
  <a href="{% url 'prompt_versions' prompt.pk %}" class="btn btn-outline-secondary btn-sm">Version History</a>
  <a href="{% url 'prompt_delete' prompt.pk %}" class="btn btn-outline-danger btn-sm">Delete</a>
  <a href="{% url 'prompt_list' %}" class="btn btn-outline-secondary btn-sm">Back to list</a>
</div>

<div class="card">
  <div class="card-body">
    <h5 class="card-title">Notes</h5>
    {% for note in notes %}
      <div class="border-bottom py-2">
        <p class="mb-1">{{ note.text }}</p>
        <small class="text-muted">{{ note.created_at }}</small>
      </div>
    {% empty %}
      <p class="text-muted">No notes yet.</p>
    {% endfor %}

    <form method="post" class="mt-3">
      {% csrf_token %}
      <textarea name="note_text" class="form-control mb-2" placeholder="Add a note..."></textarea>
      <button type="submit" class="btn btn-primary btn-sm">Add Note</button>
    </form>
  </div>
</div>

{% endblock %}
'@ | Set-Content -Path ".\prompts\templates\prompts\prompt_detail.html" -Encoding utf8

Write-Host "Writing prompts/templates/prompts/prompt_form.html ..." -ForegroundColor Cyan
@'
{% extends "base.html" %}
{% block title %}{% if editing %}Edit Prompt{% else %}Add Prompt{% endif %}{% endblock %}
{% block content %}

<h1 class="mb-4">{% if editing %}Edit Prompt{% else %}Add Prompt{% endif %}</h1>

<form method="post">
  {% csrf_token %}
  {% for field in form %}
    <div class="mb-3">
      <label class="form-label">{{ field.label }}</label>
      {{ field }}
    </div>
  {% endfor %}
  <button type="submit" class="btn btn-primary">Save</button>
  <a href="{% url 'prompt_list' %}" class="btn btn-outline-secondary">Cancel</a>
</form>

{% endblock %}
'@ | Set-Content -Path ".\prompts\templates\prompts\prompt_form.html" -Encoding utf8

Write-Host "Writing prompts/templates/prompts/prompt_versions.html ..." -ForegroundColor Cyan
@'
{% extends "base.html" %}
{% block title %}Version History{% endblock %}
{% block content %}

<h1 class="mb-3">Version History</h1>
<p>Current title: <strong>{{ prompt.title }}</strong></p>

{% for version in versions %}
  <div class="card mb-3">
    <div class="card-body">
      <h6 class="card-subtitle mb-2 text-muted">{{ version.title }} - saved {{ version.saved_at }}</h6>
      <pre class="prompt-text">{{ version.text }}</pre>
    </div>
  </div>
{% empty %}
  <p class="text-muted">No past versions yet. Versions appear here after you edit this prompt at least once.</p>
{% endfor %}

<a href="{% url 'prompt_detail' prompt.pk %}" class="btn btn-outline-secondary">Back to prompt</a>

{% endblock %}
'@ | Set-Content -Path ".\prompts\templates\prompts\prompt_versions.html" -Encoding utf8

Write-Host "Writing prompts/templates/prompts/prompt_delete_confirm.html ..." -ForegroundColor Cyan
@'
{% extends "base.html" %}
{% block title %}Delete Prompt{% endblock %}
{% block content %}

<h1 class="mb-4 text-danger">Delete Prompt</h1>
<p>Are you sure you want to delete <strong>{{ prompt.title }}</strong>? This will also delete its notes and version history. This cannot be undone.</p>

<form method="post">
  {% csrf_token %}
  <button type="submit" class="btn btn-danger">Yes, delete it</button>
  <a href="{% url 'prompt_detail' prompt.pk %}" class="btn btn-outline-secondary">Cancel</a>
</form>

{% endblock %}
'@ | Set-Content -Path ".\prompts\templates\prompts\prompt_delete_confirm.html" -Encoding utf8

Write-Host "Writing templates/registration/login.html ..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path ".\templates\registration" | Out-Null
@'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Login - PromptVault</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  <style> body { background-color: #f8f9fa; } </style>
</head>
<body>
  <div class="container" style="max-width: 400px; margin-top: 100px;">
    <h1 class="mb-4 text-center">PromptVault</h1>
    <form method="post" class="card card-body">
      {% csrf_token %}
      {% for field in form %}
        <div class="mb-3">
          <label class="form-label">{{ field.label }}</label>
          {{ field }}
        </div>
      {% endfor %}
      <button type="submit" class="btn btn-primary w-100">Log in</button>
    </form>
  </div>
</body>
</html>
'@ | Set-Content -Path ".\templates\registration\login.html" -Encoding utf8

Write-Host "Writing prompts/views.py (adding delete view) ..." -ForegroundColor Cyan
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


@login_required
def prompt_delete(request, pk):
    prompt = get_object_or_404(Prompt, pk=pk, owner=request.user)
    if request.method == 'POST':
        prompt.delete()
        return redirect('prompt_list')
    return render(request, 'prompts/prompt_delete_confirm.html', {'prompt': prompt})
'@ | Set-Content -Path ".\prompts\views.py" -Encoding utf8

Write-Host "Writing prompts/urls.py (adding delete route) ..." -ForegroundColor Cyan
@'
from django.urls import path
from . import views

urlpatterns = [
    path('', views.prompt_list, name='prompt_list'),
    path('add/', views.prompt_add, name='prompt_add'),
    path('<int:pk>/', views.prompt_detail, name='prompt_detail'),
    path('<int:pk>/edit/', views.prompt_edit, name='prompt_edit'),
    path('<int:pk>/delete/', views.prompt_delete, name='prompt_delete'),
    path('<int:pk>/versions/', views.prompt_versions, name='prompt_versions'),
    path('<int:pk>/favorite/', views.prompt_favorite_toggle, name='prompt_favorite_toggle'),
]
'@ | Set-Content -Path ".\prompts\urls.py" -Encoding utf8

Write-Host ""
Write-Host "All files written successfully." -ForegroundColor Green
Write-Host "No database changes needed for this polish pass, so no migration step." -ForegroundColor Green
Write-Host ""
Write-Host "Now run: py manage.py runserver" -ForegroundColor Green
Write-Host "Then visit http://127.0.0.1:8000/prompts/ to see the new styled version." -ForegroundColor Green
