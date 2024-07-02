module Api
  class CommentsController < ApplicationController
    before_action :authenticate_user, only: %i[create destroy]

    def index
      article = Article.find_by_slug(params[:article_slug])
      if article
        render json: { comments: article.comments.map(&:to_hash) }
      else
        render json: { errors: ['Article not found'] }, status: :not_found
      end
    end

    def create
      article = Article.find_by_slug(params[:article_slug])
      if article
        comment = Comment.new(comment_params)
        comment.author_id = @current_user.id
        article.add_comment(comment)
        if comment.save
          render json: { comment: comment.to_hash }, status: :created
        else
          render json: { errors: comment.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { errors: ['Article not found'] }, status: :not_found
      end
    end

    def destroy
      article = Article.find_by_slug(params[:article_slug])
      comment = Comment.find(params[:id]) if article

      unless article
        render json: { errors: ['Article not found'] }, status: :not_found
        return
      end

      unless comment
        render json: { errors: ['Comment not found'] }, status: :not_found
        return
      end

      if comment && comment.author_id == @current_user.id
        comment.destroy
        render json: { message: 'Comment deleted successfully' }, status: :ok
      else
        render json: { errors: ['You are not authorized to delete this comment'] }, status: :forbidden
      end
    end

    private

    def comment_params
      params.require(:comment).permit(:body)
    end
  end
end
