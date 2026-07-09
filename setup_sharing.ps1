# PromptVault - Sharing feature (public + specific-user, view-only)
# Run this from inside your promptvault project folder, with (venv) active.

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
    is_public = models.BooleanField(default=False)
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


class Share(models.Model):
    prompt = models.ForeignKey(Prompt, on_delete=models.CASCADE, related_name='shares')
    shared_with = models.ForeignKey(User, on_delete=models.CASCADE, related_name='shared_prompts')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('prompt', 'shared_with')

    def __str__(self):
        return "%s shared with %s" % (self.prompt.title, self.shared_with.username)
'@ | Set-Content -Path ".\prompts\models.py" -Encoding utf8

Write-Host "Writing prompts/admin.py ..." -ForegroundColor Cyan
@'
from django.contrib import admin
from .models import Prompt, Category, PromptVersion, Note, Share

admin.site.register(Prompt)
admin.site.register(Category)
admin.site.register(PromptVersion)
admin.site.register(Note)
admin.site.register(Share)
'@ | Set-Content -Path ".\prompts\admin.py" -Encoding utf8

Write-Host "Writing prompts/views.py ..." -ForegroundColor Cyan
@'
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.db.models import Q
from django.http import HttpResponseForbidden
from .models import Prompt, Category, PromptVersion, Note, Share
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
def shared_list(request):
    prompts = Prompt.objects.filter(
        Q(is_public=True) | Q(shares__shared_with=request.user)
    ).exclude(owner=request.user).distinct().order_by('-created_at')

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
    """Returns (prompt, is_owner) if the current user may view this prompt, else (None, None)."""
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
'@ | Set-Content -Path ".\prompts\views.py" -Encoding utf8

Write-Host "Writing prompts/urls.py ..." -ForegroundColor Cyan
@'
from django.urls import path
from . import views

urlpatterns = [
    path('', views.prompt_list, name='prompt_list'),
    path('shared/', views.shared_list, name='shared_list'),
    path('add/', views.prompt_add, name='prompt_add'),
    path('<int:pk>/', views.prompt_detail, name='prompt_detail'),
    path('<int:pk>/edit/', views.prompt_edit, name='prompt_edit'),
    path('<int:pk>/delete/', views.prompt_delete, name='prompt_delete'),
    path('<int:pk>/versions/', views.prompt_versions, name='prompt_versions'),
    path('<int:pk>/favorite/', views.prompt_favorite_toggle, name='prompt_favorite_toggle'),
    path('<int:pk>/share/', views.prompt_share, name='prompt_share'),
]
'@ | Set-Content -Path ".\prompts\urls.py" -Encoding utf8

Write-Host "Writing templates/base.html (adding Shared with me link) ..." -ForegroundColor Cyan
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
          <a class="btn btn-outline-light btn-sm me-2" href="{% url 'shared_list' %}">Shared with me</a>
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

Write-Host "Writing prompts/templates/prompts/prompt_detail.html ..." -ForegroundColor Cyan
@'
{% extends "base.html" %}
{% block title %}{{ prompt.title }}{% endblock %}
{% block content %}

{% if not is_owner %}
  <div class="alert alert-info">You are viewing this prompt because it was shared with you. It is view-only.</div>
{% endif %}

<div class="d-flex justify-content-between align-items-start">
  <h1>
    {{ prompt.title }}
    {% if is_owner %}
      <a href="{% url 'prompt_favorite_toggle' prompt.pk %}" class="star-btn" title="Toggle favorite">
        {% if prompt.is_favorite %}&#9733;{% else %}&#9734;{% endif %}
      </a>
    {% endif %}
  </h1>
</div>

{% if prompt.category %}<span class="badge bg-light text-dark tag mb-2">{{ prompt.category.name }}</span>{% endif %}
{% if prompt.is_public %}<span class="badge bg-success mb-2">Public - anyone with an account can view</span>{% endif %}

<pre class="prompt-text">{{ prompt.text }}</pre>

<p class="text-muted"><small>Created: {{ prompt.created_at }} | Updated: {{ prompt.updated_at }}</small></p>

<div class="mb-4">
  {% if is_owner %}
    <a href="{% url 'prompt_edit' prompt.pk %}" class="btn btn-primary btn-sm">Edit</a>
    <a href="{% url 'prompt_versions' prompt.pk %}" class="btn btn-outline-secondary btn-sm">Version History</a>
    <a href="{% url 'prompt_share' prompt.pk %}" class="btn btn-outline-success btn-sm">Share</a>
    <a href="{% url 'prompt_delete' prompt.pk %}" class="btn btn-outline-danger btn-sm">Delete</a>
  {% endif %}
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

    {% if is_owner %}
      <form method="post" class="mt-3">
        {% csrf_token %}
        <textarea name="note_text" class="form-control mb-2" placeholder="Add a note..."></textarea>
        <button type="submit" class="btn btn-primary btn-sm">Add Note</button>
      </form>
    {% endif %}
  </div>
</div>

{% endblock %}
'@ | Set-Content -Path ".\prompts\templates\prompts\prompt_detail.html" -Encoding utf8

Write-Host "Writing prompts/templates/prompts/prompt_share.html ..." -ForegroundColor Cyan
@'
{% extends "base.html" %}
{% block title %}Share {{ prompt.title }}{% endblock %}
{% block content %}

<h1 class="mb-4">Share "{{ prompt.title }}"</h1>

{% if error %}<div class="alert alert-danger">{{ error }}</div>{% endif %}

<div class="card mb-4">
  <div class="card-body">
    <h5 class="card-title">Public access</h5>
    <p class="text-muted">If enabled, anyone with a PromptVault account can view this prompt (view-only).</p>
    <form method="post">
      {% csrf_token %}
      <input type="hidden" name="action" value="toggle_public">
      {% if prompt.is_public %}
        <button type="submit" class="btn btn-outline-danger btn-sm">Turn off public access</button>
      {% else %}
        <button type="submit" class="btn btn-success btn-sm">Make public</button>
      {% endif %}
    </form>
  </div>
</div>

<div class="card mb-4">
  <div class="card-body">
    <h5 class="card-title">Share with a specific person</h5>
    <form method="post" class="row g-2">
      {% csrf_token %}
      <input type="hidden" name="action" value="add_user">
      <div class="col-auto">
        <input type="text" name="username" class="form-control" placeholder="Their username">
      </div>
      <div class="col-auto">
        <button type="submit" class="btn btn-primary">Share (view-only)</button>
      </div>
    </form>

    <hr>

    <h6>Currently shared with:</h6>
    {% for share in shares %}
      <div class="d-flex justify-content-between align-items-center border-bottom py-2">
        <span>{{ share.shared_with.username }}</span>
        <form method="post">
          {% csrf_token %}
          <input type="hidden" name="action" value="remove_user">
          <input type="hidden" name="share_id" value="{{ share.id }}">
          <button type="submit" class="btn btn-outline-danger btn-sm">Remove</button>
        </form>
      </div>
    {% empty %}
      <p class="text-muted">Not shared with anyone specifically yet.</p>
    {% endfor %}
  </div>
</div>

<a href="{% url 'prompt_detail' prompt.pk %}" class="btn btn-outline-secondary">Back to prompt</a>

{% endblock %}
'@ | Set-Content -Path ".\prompts\templates\prompts\prompt_share.html" -Encoding utf8

Write-Host "Writing prompts/templates/prompts/shared_list.html ..." -ForegroundColor Cyan
@'
{% extends "base.html" %}
{% block title %}Shared with me{% endblock %}
{% block content %}

<h1 class="mb-4">Shared with me</h1>

<div class="list-group">
  {% for prompt in prompts %}
    <div class="list-group-item d-flex justify-content-between align-items-center">
      <div>
        <a href="{% url 'prompt_detail' prompt.pk %}" class="fw-semibold text-decoration-none">{{ prompt.title }}</a>
        {% if prompt.category %}<span class="badge bg-light text-dark tag ms-2">{{ prompt.category.name }}</span>{% endif %}
        <small class="text-muted ms-2">by {{ prompt.owner.username }}</small>
      </div>
    </div>
  {% empty %}
    <div class="list-group-item">Nothing has been shared with you yet.</div>
  {% endfor %}
</div>

{% endblock %}
'@ | Set-Content -Path ".\prompts\templates\prompts\shared_list.html" -Encoding utf8

Write-Host ""
Write-Host "All files written successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Now running makemigrations and migrate automatically..." -ForegroundColor Cyan

py manage.py makemigrations
py manage.py migrate

Write-Host ""
Write-Host "Creating a test account (username: testuser / password: testpass123) ..." -ForegroundColor Cyan
py manage.py shell -c "from django.contrib.auth.models import User; User.objects.filter(username='testuser').exists() or User.objects.create_user('testuser', '', 'testpass123')"

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Test account created -> username: testuser  password: testpass123" -ForegroundColor Yellow
Write-Host ""
Write-Host "Now run: py manage.py runserver" -ForegroundColor Green
Write-Host "1. Log in as yourself, open a prompt, click Share." -ForegroundColor Green
Write-Host "2. Try 'Make public' OR share it with username 'testuser'." -ForegroundColor Green
Write-Host "3. Open an incognito browser window, log in as testuser / testpass123." -ForegroundColor Green
Write-Host "4. Click 'Shared with me' in the nav bar - the prompt should appear there, view-only." -ForegroundColor Green
