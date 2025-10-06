from rest_framework import serializers
from .models import User, Idea, Collaboration, Comment, Report, Category, IdeaCategory, Notification, Message 

class UserSerializer(serializers.ModelSerializer):
    social_links = serializers.JSONField(default=list, required=False)
    skills = serializers.JSONField(default=list, required=False)
    interests = serializers.JSONField(default=list, required=False)
    profile_pic = serializers.SerializerMethodField()
    comment_count = serializers.IntegerField(read_only=True, source='comments.count')
    comment_count = serializers.IntegerField(read_only=True, source='comments.count')
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password', 'first_name', 'last_name', 'bio', 'profession', 
                  'social_links', 'skills', 'interests', 'profile_pic', 'created_at', 'comment_count', ]
        extra_kwargs = {
            'password': {'write_only': True, 'required': True},
            'first_name': {'required': False},
            'last_name': {'required': False},
            'bio': {'required': False},
            'profession': {'required': False},
            'skills': {'required': False},
            'interests': {'required': False},
            'profile_pic': {'required': False},
            'social_links': {'required': False, 'allow_null': True}
        }

    def get_profile_pic(self, obj):
        if obj.profile_pic and hasattr(obj.profile_pic, 'url'):
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.profile_pic.url)
            return obj.profile_pic.url
        return '/media/profile_pics/default.jpg'

    def validate_social_links(self, value):
        if value is None:
            return []
        if not isinstance(value, list):
            raise serializers.ValidationError("social_links must be a list")
        for link in value:
            if not isinstance(link, str):
                raise serializers.ValidationError("Each social link must be a string URL")
            if not link:
                raise serializers.ValidationError("URL cannot be empty")
        if len(value) > 3:
            raise serializers.ValidationError("Maximum 3 social links allowed")
        return value

    def validate_interests(self, value):
        if value is None:
            return []
        if not isinstance(value, list):
            raise serializers.ValidationError("interests must be a list")
        valid_categories = Category.objects.values_list('name', flat=True)
        invalid_interests = [interest for interest in value if interest not in valid_categories]
        if invalid_interests:
            raise serializers.ValidationError(f"Invalid interests: {invalid_interests}")
        if len(value) > 5:
            raise serializers.ValidationError("Cannot select more than 5 interests")
        return value

    def validate_skills(self, value):
        if value is None:
            return []
        if not isinstance(value, list):
            raise serializers.ValidationError("skills must be a list")
        return value

    def create(self, validated_data):
        password = validated_data.get('password')
        if not password:
            raise serializers.ValidationError({'password': 'This field is required.'})
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=password
        )
        user.first_name = validated_data.get('first_name', '')
        user.last_name = validated_data.get('last_name', '')
        user.bio = validated_data.get('bio', '')
        user.profession = validated_data.get('profession', '')
        user.social_links = validated_data.get('social_links', [])
        user.skills = validated_data.get('skills', [])
        user.interests = validated_data.get('interests', [])
        if 'profile_pic' in validated_data:
            user.profile_pic = validated_data['profile_pic']
        user.save()
        return user

    def update(self, instance, validated_data):
        instance.first_name = validated_data.get('first_name', instance.first_name)
        instance.last_name = validated_data.get('last_name', instance.last_name)
        instance.bio = validated_data.get('bio', instance.bio)
        instance.profession = validated_data.get('profession', instance.profession)
        instance.social_links = validated_data.get('social_links', instance.social_links)
        instance.skills = validated_data.get('skills', instance.skills)
        instance.interests = validated_data.get('interests', instance.interests)
        if 'profile_pic' in validated_data:
            instance.profile_pic = validated_data['profile_pic']
        instance.save()
        return instance

    def _parse_list(self, value):
        if isinstance(value, str):
            return [item.strip() for item in value.split(',') if item.strip()]
        return value if value else []

class IdeaSerializer(serializers.ModelSerializer):
    time_since = serializers.CharField(read_only=True)
    categories = serializers.SerializerMethodField()
    user = UserSerializer(read_only=True)
    user_id = serializers.PrimaryKeyRelatedField(
        write_only=True, queryset=User.objects.all(), source='user', required=False
    )
    like_count = serializers.IntegerField(read_only=True)
    is_liked = serializers.SerializerMethodField()

    class Meta:
        model = Idea
        fields = [
            'id', 'title', 'short_description', 'description', 'visibility', 
            'user', 'user_id', 'categories', 'created_at', 'time_since', 
            'files', 'like_count', 'is_liked', 'comment_count',
        ]
        extra_kwargs = {
            'title': {'required': True},
            'description': {'required': True},
            'short_description': {'required': False},
            'visibility': {'required': False},
            'files': {'read_only': True},
        }

    def get_categories(self, obj):
        categories = IdeaCategory.objects.filter(idea=obj)
        return [cat.category.name for cat in categories]

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(user=request.user).exists()
        return False

    def create(self, validated_data):
        print("Validated data in serializer:", validated_data)
        categories = validated_data.pop('categories', [])
        user = validated_data.get('user')
        if not user:
            request = self.context.get('request')
            if request and hasattr(request, 'user') and request.user.is_authenticated:
                validated_data['user'] = request.user
            else:
                raise serializers.ValidationError("User must be provided or authenticated")
        idea = Idea.objects.create(**validated_data)
        for category_name in categories:
            category, created = Category.objects.get_or_create(name=category_name)
            IdeaCategory.objects.get_or_create(idea=idea, category=category)
        return idea

class CollaborationSerializer(serializers.ModelSerializer):
    idea = IdeaSerializer(read_only=True)
    collaborator = UserSerializer(read_only=True)

    class Meta:
        model = Collaboration
        fields = ['id', 'idea', 'collaborator', 'status']

class CommentSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)  # Make user read-only, provided by view
    idea = serializers.PrimaryKeyRelatedField(read_only=True)  # Make idea read-only, provided by view

    class Meta:
        model = Comment
        fields = ['id', 'idea', 'user', 'content', 'created_at']
        extra_kwargs = {
            'content': {'required': True},  # Ensure content is required
        }

class ReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = Report
        fields = '__all__'

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'

class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True)

    def validate(self, data):
        user = self.context['request'].user
        if not user.check_password(data['old_password']):
            raise serializers.ValidationError({'old_password': 'Incorrect password'})
        if len(data['new_password']) < 8:
            raise serializers.ValidationError({'new_password': 'New password must be at least 8 characters'})
        return data

class NotificationSerializer(serializers.ModelSerializer):
    sender = UserSerializer(read_only=True)
    idea = IdeaSerializer(read_only=True)
    collab_id = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = '__all__'

    def get_collab_id(self, obj):
        if obj.type.startswith('collab') and obj.sender and obj.idea:
            collab = Collaboration.objects.filter(idea=obj.idea, collaborator=obj.sender, status='pending').first()
            return collab.id if collab else None
        return None
    
class MessageSerializer(serializers.ModelSerializer):
    sender = serializers.PrimaryKeyRelatedField(queryset=User.objects.all(), write_only=True)
    sender_details = UserSerializer(source='sender', read_only=True)

    class Meta:
        model = Message
        fields = ['id', 'idea', 'sender', 'sender_details', 'content', 'created_at']

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        representation['sender'] = representation.pop('sender_details', None)
        return representation