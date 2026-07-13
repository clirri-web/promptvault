from django.urls import path
from . import views

urlpatterns = [
    path('dashboard/', views.dashboard, name='dashboard'),
    path('', views.prompt_list, name='prompt_list'),
    path('shared/', views.shared_list, name='shared_list'),
    path('settings/', views.settings_page, name='settings_page'),
    path('export/', views.export_prompts, name='export_prompts'),
    path('import/', views.import_prompts, name='import_prompts'),
    path('add/', views.prompt_add, name='prompt_add'),
    path('<int:pk>/', views.prompt_detail, name='prompt_detail'),
    path('<int:pk>/edit/', views.prompt_edit, name='prompt_edit'),
    path('<int:pk>/use/', views.prompt_use_template, name='prompt_use_template'),
    path('<int:pk>/delete/', views.prompt_delete, name='prompt_delete'),
    path('<int:pk>/versions/', views.prompt_versions, name='prompt_versions'),
    path('<int:pk>/versions/<int:version_id>/restore/', views.prompt_version_restore, name='prompt_version_restore'),
    path('<int:pk>/favorite/', views.prompt_favorite_toggle, name='prompt_favorite_toggle'),
    path('<int:pk>/pin/', views.prompt_pin_toggle, name='prompt_pin_toggle'),
    path('<int:pk>/archive/', views.prompt_archive_toggle, name='prompt_archive_toggle'),
    path('<int:pk>/duplicate/', views.prompt_duplicate, name='prompt_duplicate'),
    path('<int:pk>/share/', views.prompt_share, name='prompt_share'),
    path('<int:pk>/attachments/add/', views.prompt_attachment_add, name='prompt_attachment_add'),
    path('<int:pk>/attachments/<int:attachment_id>/delete/', views.prompt_attachment_delete, name='prompt_attachment_delete'),
]
