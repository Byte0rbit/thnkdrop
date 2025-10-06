from django.contrib import admin
from .models import User, Idea, Collaboration, Comment, Report, Category, IdeaCategory

# Define an inline for IdeaCategory
class IdeaCategoryInline(admin.TabularInline):
    model = IdeaCategory
    extra = 1  # Allows adding 1 new category by default

# Customize the Idea admin
@admin.register(Idea)
class IdeaAdmin(admin.ModelAdmin):
    inlines = [IdeaCategoryInline]
    list_display = ('title', 'visibility', 'user', 'created_at')  # Optional: shows these columns in list view

# Register other models
admin.site.register(User)
admin.site.register(Collaboration)
admin.site.register(Comment)
admin.site.register(Report)
admin.site.register(Category)