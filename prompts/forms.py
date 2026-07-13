from django import forms
from .models import Prompt, Tag


class PromptForm(forms.ModelForm):
    tags = forms.ModelMultipleChoiceField(
        queryset=Tag.objects.all(),
        required=False,
        widget=forms.CheckboxSelectMultiple,
    )

    class Meta:
        model = Prompt
        fields = ['title', 'text', 'category', 'ai_model', 'rating', 'tags', 'is_template']
        widgets = {
            'rating': forms.Select(choices=[
                (0, 'No rating'), (1, '1 star'), (2, '2 stars'),
                (3, '3 stars'), (4, '4 stars'), (5, '5 stars'),
            ]),
        }
        labels = {
            'is_template': 'This is a reusable template (supports {{variable}} placeholders)',
        }
