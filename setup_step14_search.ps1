# PromptVault - Step 14 (Search) - Automated file writer
# Run this from inside your promptvault project folder, with (venv) active.

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\manage.py")) {
    Write-Host "ERROR: manage.py not found in this folder." -ForegroundColor Red
    Write-Host "Please 'cd' into your promptvault project folder first, then run this script again." -ForegroundColor Red
    exit 1
}

Write-Host "Writing prompts/views.py ..." -ForegroundColor Cyan
@'
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.db.models import Q
from .models import Prompt, Category
from .forms import PromptForm


@login_required
def prompt_list(request):
    prompts = Prompt.objects.filter(owner=request.user).order_by('-created_at')

    category_id = request.GET.get('category')
    if category_id:
        prompts = prompts.filter(category_id=category_id)

    search_query = request.GET.get('q', '').strip()
    if search_query:
        prompts = prompts.filter(
            Q(title__icontains=search_query) | Q(text__icontains=search_query)
        )

    categories = Category.objects.all()

    return render(request, 'prompts/prompt_list.html', {
        'prompts': prompts,
        'categories': categories,
        'selected_category': category_id,
        'search_query': search_query,
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
    .filterbar { margin-bottom: 16px; display: flex; gap: 12px; align-items: center; }
    select, input[type=text] { padding: 6px; }
    .tag { display: inline-block; background: #eef2ff; color: #3730a3; padding: 2px 8px; border-radius: 10px; font-size: 12px; margin-left: 8px; }
    button { padding: 6px 14px; background: #2563eb; color: white; border: none; border-radius: 4px; cursor: pointer; }
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
    <button type="submit">Search</button>
    <a href="{% url 'prompt_list' %}">Clear</a>
  </form>

  <ul>
    {% for prompt in prompts %}
      <li>
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

Write-Host ""
Write-Host "All files written successfully." -ForegroundColor Green
Write-Host "No database changes needed for this feature, so no migration step." -ForegroundColor Green
Write-Host ""
Write-Host "Now run: py manage.py runserver" -ForegroundColor Green
Write-Host "Then visit http://127.0.0.1:8000/prompts/ and try the search box." -ForegroundColor Green
