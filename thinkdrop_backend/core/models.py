from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.exceptions import ValidationError

def validate_social_links(value):
    if not isinstance(value, list):
        raise ValidationError("Social links must be a list.")
    for link in value:
        if not isinstance(link, str):
            raise ValidationError("Each social link must be a string URL.")
        if not link:
            raise ValidationError("URL cannot be empty.")
    return value

class User(AbstractUser):
    bio = models.TextField(blank=True)
    profession = models.CharField(max_length=100, blank=True)
    social_links = models.JSONField(default=list, blank=True, validators=[validate_social_links])
    SKILL_CHOICES = [
        "Coding", "Design", "Marketing", "Writing", "Photography", "Teaching", "Research",
        "Data Analysis", "Project Management", "Music", "Art", "Cooking"
    ]
    skills = models.JSONField(default=list, blank=True)
    interests = models.JSONField(default=list, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    profile_pic = models.ImageField(upload_to='profile_pics/', null=True, blank=True)

    def __str__(self):
        return self.username

class Idea(models.Model):
    VISIBILITY_CHOICES = [
        ('private', 'Private'),
        ('public', 'Public'),
        ('partial', 'Partial'),
    ]
    title = models.CharField(max_length=200)
    short_description = models.CharField(max_length=500, blank=True, null=True)
    description = models.TextField()
    visibility = models.CharField(max_length=10, choices=VISIBILITY_CHOICES, default='private')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='ideas')
    created_at = models.DateTimeField(auto_now_add=True)
    files = models.JSONField(default=list, blank=True)

    def __str__(self):
        return self.title

    @property
    def like_count(self):
        return self.likes.count()
    
    @property
    def comment_count(self):
        return self.comments.count()

class Collaboration(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected'),
    ]
    idea = models.ForeignKey(Idea, on_delete=models.CASCADE, related_name='collaborations')
    collaborator = models.ForeignKey(User, on_delete=models.CASCADE, related_name='collaborations')
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')

    class Meta:
        unique_together = ('idea', 'collaborator')

    def __str__(self):
        return f"{self.collaborator} on {self.idea}"

class Comment(models.Model):
    idea = models.ForeignKey(Idea, on_delete=models.CASCADE, related_name='comments')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='comments')
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Comment by {self.user} on {self.idea}"

class Report(models.Model):
    idea = models.ForeignKey(Idea, on_delete=models.CASCADE, related_name='reports')
    reporter = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reports')
    reason = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Report on {self.idea} by {self.reporter}"

class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)

    def __str__(self):
        return self.name

class IdeaCategory(models.Model):
    idea = models.ForeignKey(Idea, on_delete=models.CASCADE, related_name='idea_categories')
    category = models.ForeignKey(Category, on_delete=models.CASCADE, related_name='ideas_category')

    class Meta:
        unique_together = ('idea', 'category')

    def __str__(self):
        return f"{self.category} for {self.idea}"

class Like(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='likes')
    idea = models.ForeignKey(Idea, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'idea')

    def __str__(self):
        return f"{self.user} likes {self.idea}"
    
class Notification(models.Model):
    TYPE_CHOICES = [
        ('collab_request', 'Collaboration Request'),
        ('collab_approved', 'Collaboration Approved'),
        ('collab_rejected', 'Collaboration Rejected'),
        ('like', 'Like'),
        ('comment', 'Comment'),
    ]
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')  # Recipient
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sent_notifications', null=True, blank=True)  # Who triggered it
    idea = models.ForeignKey(Idea, on_delete=models.CASCADE, null=True, blank=True)
    type = models.CharField(max_length=50, choices=TYPE_CHOICES)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.type} for {self.user} on {self.idea}"

class Message(models.Model):
    idea = models.ForeignKey(Idea, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(User, on_delete=models.CASCADE)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Message by {self.sender} on {self.idea}"