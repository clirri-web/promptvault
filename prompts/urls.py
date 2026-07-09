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
