from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.contrib.auth import authenticate
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser
from .models import User, Idea, Category, IdeaCategory, Report, Like, Comment, Notification, Message, Collaboration
from .serializers import UserSerializer, IdeaSerializer, CategorySerializer, ReportSerializer, ChangePasswordSerializer, CommentSerializer, NotificationSerializer, MessageSerializer, CollaborationSerializer
from django.utils import timezone
from rest_framework.pagination import PageNumberPagination
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from django.db.models import Q
import os
import json
from django.db.models import Q  
class RegisterView(APIView):
    def post(self, request):
        serializer = UserSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            refresh = RefreshToken.for_user(user)
            return Response({
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class LoginView(APIView):
    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')
        user = authenticate(request, username=email, password=password)
        if user is not None:
            refresh = RefreshToken.for_user(user)
            return Response({
                'refresh': str(refresh),
                'access': str(refresh.access_token),
                'user_id': user.id,
            }, status=status.HTTP_200_OK)
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)

class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            user = request.user
            user.set_password(serializer.validated_data['new_password'])
            user.save()
            # Invalidate existing tokens
            RefreshToken.for_user(user).blacklist()
            # Generate new tokens
            refresh = RefreshToken.for_user(user)
            return Response({
                'message': 'Password changed successfully',
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class DeleteAccountView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request):
        user = request.user
        Idea.objects.filter(user=user).delete()
        Like.objects.filter(user=user).delete()
        Report.objects.filter(reporter=user).delete()
        RefreshToken.for_user(user).blacklist()
        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

class ProfileUpdateView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]

    def patch(self, request):
        serializer = UserSerializer(request.user, data=request.data, partial=True, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

class CategoryListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        categories = Category.objects.all()
        serializer = CategorySerializer(categories, many=True)
        return Response(serializer.data)

class IdeaCreateView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]

    def post(self, request):
        print("Received idea data:", request.data)
        serializer = IdeaSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            idea = serializer.save()
            if 'categories' in request.data:
                try:
                    categories = request.data['categories']
                    if isinstance(categories, str):
                        categories = json.loads(categories)
                    if isinstance(categories, (list, tuple)):
                        for category_name in categories:
                            category, created = Category.objects.get_or_create(name=category_name)
                            IdeaCategory.objects.get_or_create(idea=idea, category=category)
                except json.JSONDecodeError:
                    return Response({"categories": "Invalid JSON format"}, status=status.HTTP_400_BAD_REQUEST)
            file_urls = []
            files = request.FILES.getlist('files')
            for file in files:
                file_name = default_storage.get_available_name(f'idea_files/{file.name}')
                default_storage.save(file_name, ContentFile(file.read()))
                file_url = f'{request.build_absolute_uri("/")[:-1]}{default_storage.url(file_name)}'
                file_urls.append(file_url)
            idea.files = file_urls
            idea.save()
            serializer = IdeaSerializer(idea, context={'request': request})
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        print("Serializer errors:", serializer.errors)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class IdeaPagination(PageNumberPagination):
    page_size = 10
    page_size_query_param = 'page_size'
    max_page_size = 50

class IdeaListView(APIView):
    permission_classes = [IsAuthenticated]
    pagination_class = IdeaPagination

    def get(self, request):
        user = request.user
        today = timezone.now()
        interest_categories = user.interests if user.interests else []
        user_filter = request.query_params.get('user', None)
        visibility = request.query_params.get('visibility', None)

        if user_filter and user_filter.isdigit():
            ideas = Idea.objects.filter(user_id=int(user_filter))
        else:
            ideas = Idea.objects.filter(visibility__in=['public', 'partial'])

        if visibility:
            ideas = ideas.filter(visibility=visibility.lower())

        prioritized_ideas = []
        for idea in ideas:
            categories = [cat.category.name for cat in idea.idea_categories.all()]
            if any(interest in categories for interest in interest_categories):
                prioritized_ideas.append(idea)
            else:
                prioritized_ideas.append(idea)

        if len(prioritized_ideas) < IdeaPagination.page_size:
            remaining_ideas = Idea.objects.filter(
                visibility__in=['public', 'partial']
            ).exclude(id__in=[idea.id for idea in prioritized_ideas]).order_by('-created_at')
            if user_filter and user_filter.isdigit():
                remaining_ideas = Idea.objects.filter(user_id=int(user_filter)).exclude(id__in=[idea.id for idea in prioritized_ideas]).order_by('-created_at')
            if visibility:
                remaining_ideas = remaining_ideas.filter(visibility=visibility.lower())
            prioritized_ideas += list(remaining_ideas)[:IdeaPagination.page_size - len(prioritized_ideas)]

        paginator = IdeaPagination()
        page = paginator.paginate_queryset(prioritized_ideas, request)
        if page is not None:
            serializer = IdeaSerializer(page, many=True, context={'request': request})
            for data in serializer.data:
                created_at = data['created_at']
                time_diff = today - timezone.datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                days = time_diff.days
                total_seconds = time_diff.total_seconds()
                hours = int(total_seconds // 3600)
                minutes = int((total_seconds % 3600) // 60)
                seconds = int(total_seconds % 60)
                if days > 0:
                    data['time_since'] = f"{days}d"
                elif hours > 0:
                    data['time_since'] = f"{hours}h"
                elif minutes > 0:
                    data['time_since'] = f"{minutes}m"
                else:
                    data['time_since'] = f"{seconds}s"
                print(f"Idea {data['id']}: created_at={created_at}, time_since={data['time_since']}")
            return paginator.get_paginated_response(serializer.data)

        serializer = IdeaSerializer(prioritized_ideas, many=True, context={'request': request})
        for data in serializer.data:
            created_at = data['created_at']
            time_diff = today - timezone.datetime.fromisoformat(created_at.replace('Z', '+00:00'))
            days = time_diff.days
            total_seconds = time_diff.total_seconds()
            hours = int(total_seconds // 3600)
            minutes = int((total_seconds % 3600) // 60)
            seconds = int(total_seconds % 60)
            if days > 0:
                data['time_since'] = f"{days}d"
            elif hours > 0:
                data['time_since'] = f"{hours}h"
            elif minutes > 0:
                data['time_since'] = f"{minutes}m"
            else:
                data['time_since'] = f"{seconds}s"
            print(f"Idea {data['id']}: created_at={created_at}, time_since={data['time_since']}")
        return Response(serializer.data)

class IdeaUpdateView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]

    def patch(self, request, pk):
        try:
            idea = Idea.objects.get(pk=pk, user=request.user)
        except Idea.DoesNotExist:
            return Response({"error": "Idea not found or you don't have permission"}, status=status.HTTP_404_NOT_FOUND)

        serializer = IdeaSerializer(idea, data=request.data, partial=True, context={'request': request})
        if serializer.is_valid():
            if 'categories' in request.data:
                try:
                    categories = request.data['categories']
                    if isinstance(categories, str):
                        categories = json.loads(categories)
                    if isinstance(categories, (list, tuple)):
                        IdeaCategory.objects.filter(idea=idea).delete()
                        for category_name in categories:
                            category, created = Category.objects.get_or_create(name=category_name)
                            IdeaCategory.objects.get_or_create(idea=idea, category=category)
                except json.JSONDecodeError:
                    return Response({"categories": "Invalid JSON format"}, status=status.HTTP_400_BAD_REQUEST)

            existing_files = request.data.get('existing_files', [])
            if isinstance(existing_files, str):
                existing_files = json.loads(existing_files)
            file_urls = existing_files
            files = request.FILES.getlist('files')
            for file in files:
                file_name = default_storage.get_available_name(f'idea_files/{file.name}')
                default_storage.save(file_name, ContentFile(file.read()))
                file_url = f'{request.build_absolute_uri("/")[:-1]}{default_storage.url(file_name)}'
                file_urls.append(file_url)
            idea.files = file_urls

            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class IdeaDeleteView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        try:
            idea = Idea.objects.get(pk=pk, user=request.user)
        except Idea.DoesNotExist:
            return Response({"error": "Idea not found or you don't have permission"}, status=status.HTTP_404_NOT_FOUND)
        idea.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

class ReportCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ReportSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            serializer.save(reporter=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class LikeIdeaView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, idea_id):
        try:
            idea = Idea.objects.get(id=idea_id)
            like, created = Like.objects.get_or_create(user=request.user, idea=idea)
            if not created:
                like.delete()
                return Response({'message': 'Idea unliked', 'like_count': idea.like_count, 'is_liked': False}, status=status.HTTP_200_OK)
            # Notification for like
            if idea.user != request.user:
                Notification.objects.create(
                    user=idea.user,
                    sender=request.user,
                    idea=idea,
                    type='like',
                    message=f"{request.user.username} liked your idea '{idea.title}'"
                )
            return Response({'message': 'Idea liked', 'like_count': idea.like_count, 'is_liked': True}, status=status.HTTP_201_CREATED)
        except Idea.DoesNotExist:
            return Response({'error': 'Idea not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

class SearchView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        query = request.query_params.get('q', '').strip()
        if not query:
            return Response({
                'ideas': [],
                'categories': [],
                'users': []
            }, status=status.HTTP_200_OK)

        # Search ideas
        ideas = Idea.objects.filter(
            Q(title__icontains=query) |
            Q(short_description__icontains=query) |
            Q(description__icontains=query),
            visibility__in=['public', 'partial']
        )
        idea_serializer = IdeaSerializer(ideas, many=True, context={'request': request})

        # Search categories
        categories = Category.objects.filter(name__icontains=query)
        category_serializer = CategorySerializer(categories, many=True)

        # Search users
        users = User.objects.filter(
            Q(username__icontains=query) |
            Q(email__icontains=query)
        )
        user_serializer = UserSerializer(users, many=True)

        # Add time_since to ideas
        today = timezone.now()
        for data in idea_serializer.data:
            created_at = data['created_at']
            time_diff = today - timezone.datetime.fromisoformat(created_at.replace('Z', '+00:00'))
            days = time_diff.days
            total_seconds = time_diff.total_seconds()
            hours = int(total_seconds // 3600)
            minutes = int((total_seconds % 3600) // 60)
            seconds = int(total_seconds % 60)
            if days > 0:
                data['time_since'] = f"{days}d"
            elif hours > 0:
                data['time_since'] = f"{hours}h"
            elif minutes > 0:
                data['time_since'] = f"{minutes}m"
            else:
                data['time_since'] = f"{seconds}s"

        return Response({
            'ideas': idea_serializer.data,
            'categories': category_serializer.data,
            'users': user_serializer.data
        }, status=status.HTTP_200_OK)
    
class CommentListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, idea_id):
        comments = Comment.objects.filter(idea_id=idea_id).order_by('-created_at')
        serializer = CommentSerializer(comments, many=True)
        return Response(serializer.data)

    def post(self, request, idea_id):
        try:
            idea = Idea.objects.get(id=idea_id)
        except Idea.DoesNotExist:
            return Response({"error": "Idea not found"}, status=status.HTTP_404_NOT_FOUND)
    
        serializer = CommentSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(user=request.user, idea=idea)
            # Notification for comment
            if idea.user != request.user:
                Notification.objects.create(
                    user=idea.user,
                    sender=request.user,
                    idea=idea,
                    type='comment',
                    message=f"{request.user.username} commented on your idea '{idea.title}'"
                )
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class CommentDeleteView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, comment_id):
        try:
            comment = Comment.objects.get(id=comment_id, user=request.user)
            comment.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Comment.DoesNotExist:
            return Response({"error": "Comment not found or you don't own it"}, status=status.HTTP_404_NOT_FOUND)
        
class CollaborationRequestView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, idea_id):
        try:
            idea = Idea.objects.get(id=idea_id)
            if idea.user == request.user:
                return Response({'error': 'Cannot request collaboration on your own idea'}, status=status.HTTP_400_BAD_REQUEST)
            collab, created = Collaboration.objects.get_or_create(idea=idea, collaborator=request.user, defaults={'status': 'pending'})
            if not created and collab.status != 'rejected':
                return Response({'error': 'Collaboration request already exists'}, status=status.HTTP_400_BAD_REQUEST)
            if collab.status == 'rejected':
                collab.status = 'pending'
                collab.save()
            
            # Create notification for idea owner
            Notification.objects.create(
                user=idea.user,
                sender=request.user,
                idea=idea,
                type='collab_request',
                message=f"{request.user.username} requested to collaborate on your idea '{idea.title}'"
            )
            return Response({'message': 'Collaboration request sent'}, status=status.HTTP_201_CREATED)
        except Idea.DoesNotExist:
            return Response({'error': 'Idea not found'}, status=status.HTTP_404_NOT_FOUND)

class CollaborationApproveRejectView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, collab_id):
        try:
            collab = Collaboration.objects.get(id=collab_id, idea__user=request.user)
            action = request.data.get('action')  # 'approve' or 'reject'
            if action == 'approve':
                collab.status = 'accepted'
                collab.save()
                Notification.objects.create(
                    user=collab.collaborator,
                    sender=request.user,
                    idea=collab.idea,
                    type='collab_approved',
                    message=f"Your collaboration request for '{collab.idea.title}' was approved"
                )
                return Response({'message': 'Collaboration approved'}, status=status.HTTP_200_OK)
            elif action == 'reject':
                collab.status = 'rejected'
                collab.save()
                Notification.objects.create(
                    user=collab.collaborator,
                    sender=request.user,
                    idea=collab.idea,
                    type='collab_rejected',
                    message=f"Your collaboration request for '{collab.idea.title}' was rejected"
                )
                return Response({'message': 'Collaboration rejected'}, status=status.HTTP_200_OK)
            else:
                return Response({'error': 'Invalid action'}, status=status.HTTP_400_BAD_REQUEST)
        except Collaboration.DoesNotExist:
            return Response({'error': 'Collaboration not found or you are not the owner'}, status=status.HTTP_404_NOT_FOUND)

class CollaborationListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Find all relevant ideas (where user is owner or collaborator)
        relevant_ideas = Idea.objects.filter(
            Q(collaborations__collaborator=request.user) | Q(user=request.user)
        ).distinct()
        
        # Get all collaborations for those ideas (status=accepted only)
        collabs = Collaboration.objects.filter(
            idea__in=relevant_ideas,
            status='accepted'
        ).select_related('idea', 'collaborator')
        
        serializer = CollaborationSerializer(collabs, many=True)
        return Response(serializer.data)
        
class NotificationMarkReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, notification_id):
        try:
            notification = Notification.objects.get(id=notification_id, user=request.user)
            notification.is_read = True
            notification.save()
            return Response({'message': 'Notification marked as read'})
        except Notification.DoesNotExist:
            return Response({'error': 'Notification not found'}, status=status.HTTP_404_NOT_FOUND)

class MessageListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, idea_id):
        idea = Idea.objects.get(id=idea_id)
        # Check if user is owner or accepted collaborator
        if idea.user != request.user and not Collaboration.objects.filter(
            idea=idea, collaborator=request.user, status='accepted'
        ).exists():
            return Response({'detail': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        messages = Message.objects.filter(idea=idea).order_by('created_at')
        serializer = MessageSerializer(messages, many=True)
        return Response(serializer.data)

    def post(self, request, idea_id):
        idea = Idea.objects.get(id=idea_id)
        # Check if user is owner or accepted collaborator
        if idea.user != request.user and not Collaboration.objects.filter(
            idea=idea, collaborator=request.user, status='accepted'
        ).exists():
            return Response({'detail': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        data = request.data.copy()
        data['idea'] = idea_id
        data['sender'] = request.user.id
        serializer = MessageSerializer(data=data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
class NotificationListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        notifications = Notification.objects.filter(user=request.user).order_by('-created_at')
        serializer = NotificationSerializer(notifications, many=True)
        return Response(serializer.data)

class GroupMembersView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, idea_id):
        try:
            idea = Idea.objects.get(id=idea_id)
            # Check access: Owner or accepted collaborator
            if idea.user != request.user and not Collaboration.objects.filter(
                idea=idea, collaborator=request.user, status='accepted'
            ).exists():
                return Response({'detail': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
            
            # Get owner and all accepted collaborators
            members = []
            members.append({
                'id': idea.user.id,
                'username': idea.user.username,
                'is_owner': True
            })
            collabs = Collaboration.objects.filter(idea=idea, status='accepted')
            for collab in collabs:
                members.append({
                    'id': collab.collaborator.id,
                    'username': collab.collaborator.username,
                    'is_owner': False
                })
            
            return Response({'members': members})
        except Idea.DoesNotExist:
            return Response({'error': 'Idea not found'}, status=status.HTTP_404_NOT_FOUND)

class RemoveMemberView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        idea_id = request.data.get('idea_id')
        member_id = request.data.get('member_id')
        try:
            if not idea_id or not member_id:
                return Response({'error': 'idea_id and member_id required'}, status=status.HTTP_400_BAD_REQUEST)
            idea = Idea.objects.get(id=idea_id)
            # Only owner can remove
            if idea.user != request.user:
                return Response({'detail': 'Only owner can remove members'}, status=status.HTTP_403_FORBIDDEN)
            # Find and delete collaboration for this member
            collab = Collaboration.objects.get(idea=idea, collaborator_id=member_id, status='accepted')
            collab.delete()
            return Response({'message': 'Member removed successfully'})
        except (Idea.DoesNotExist, Collaboration.DoesNotExist):
            return Response({'error': 'Idea or member not found'}, status=status.HTTP_404_NOT_FOUND)

class LeaveGroupView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        idea_id = request.data.get('idea_id')
        try:
            if not idea_id:
                return Response({'error': 'idea_id required'}, status=status.HTTP_400_BAD_REQUEST)
            # Find and delete user's collaboration for this idea
            collab = Collaboration.objects.get(idea_id=idea_id, collaborator=request.user, status='accepted')
            collab.delete()
            return Response({'message': 'You left the group'})
        except Collaboration.DoesNotExist:
            return Response({'error': 'You are not a member of this group'}, status=status.HTTP_404_NOT_FOUND)