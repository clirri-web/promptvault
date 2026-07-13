from django.contrib import admin
from django.urls import path, include
from django.contrib.auth import views as auth_views
from django.conf import settings
from django.views.static import serve as serve_static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('prompts/', include('prompts.urls')),
    path('login/', auth_views.LoginView.as_view(template_name='registration/login.html'), name='login'),
    path('logout/', auth_views.LogoutView.as_view(next_page='login'), name='logout'),
    # Serving media files directly like this is only appropriate for a small,
    # internal, non-public app like this one (not a general production practice).
    path('media/<path:path>', serve_static, {'document_root': settings.MEDIA_ROOT}),
]
