from django.contrib import admin
from .models import Prompt, Category, PromptVersion, Note, Share, Tag, Attachment


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'icon', 'color', 'prompt_count')
    search_fields = ('name',)

    def prompt_count(self, obj):
        return obj.prompts.count()
    prompt_count.short_description = 'Prompts'


@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    list_display = ('name', 'color', 'prompt_count')
    search_fields = ('name',)

    def prompt_count(self, obj):
        return obj.prompts.count()
    prompt_count.short_description = 'Prompts'


class NoteInline(admin.TabularInline):
    model = Note
    extra = 0
    readonly_fields = ('created_at',)


class AttachmentInline(admin.TabularInline):
    model = Attachment
    extra = 0
    readonly_fields = ('uploaded_at',)


@admin.register(Prompt)
class PromptAdmin(admin.ModelAdmin):
    list_display = (
        'title', 'owner', 'category', 'ai_model', 'rating',
        'is_favorite', 'is_pinned', 'is_archived', 'is_public',
        'is_template', 'created_at',
    )
    list_filter = (
        'category', 'ai_model', 'is_favorite', 'is_pinned',
        'is_archived', 'is_public', 'is_template', 'owner',
    )
    search_fields = ('title', 'text', 'owner__username')
    filter_horizontal = ('tags',)
    inlines = [NoteInline, AttachmentInline]
    date_hierarchy = 'created_at'


@admin.register(PromptVersion)
class PromptVersionAdmin(admin.ModelAdmin):
    list_display = ('prompt', 'title', 'saved_at')
    search_fields = ('title', 'prompt__title')
    list_filter = ('saved_at',)


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display = ('prompt', 'text', 'created_at')
    search_fields = ('text', 'prompt__title')


@admin.register(Share)
class ShareAdmin(admin.ModelAdmin):
    list_display = ('prompt', 'shared_with', 'can_edit', 'created_at')
    list_filter = ('can_edit',)
    search_fields = ('prompt__title', 'shared_with__username')


@admin.register(Attachment)
class AttachmentAdmin(admin.ModelAdmin):
    list_display = ('prompt', 'label', 'file', 'link', 'uploaded_at')
    search_fields = ('label', 'prompt__title')
