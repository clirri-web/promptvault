from django.urls import path
from . import views

urlpatterns = [
    path('', views.prompt_list, name='prompt_list'),
    path('add/', views.prompt_add, name='prompt_add'),
    path('<int:pk>/', views.prompt_detail, name='prompt_detail'),
]