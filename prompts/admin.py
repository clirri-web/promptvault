from django.contrib import admin
from .models import Prompt, Category, PromptVersion, Note, Share

admin.site.register(Prompt)
admin.site.register(Category)
admin.site.register(PromptVersion)
admin.site.register(Note)
admin.site.register(Share)
