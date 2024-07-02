class ArticlesController < ApplicationController
  before_action :authenticate_user, only: %i[create update destroy favorite unfavorite feed]

  def index
    @articles = set_articles_based_on_feed
    @tags = Tag.all || []

    respond_to do |format|
      format.html { render :index }
      format.json { render json: { articles: @articles, tags: @tags } }
    end
  end

  def show
    @article = Article.find_by_slug(params[:id])
    @is_favorited = current_user.favorited?(@article) if current_user
    @is_followed = current_user.following?(@article.author) if current_user

    if @article
      @comment = Comment.new

      respond_to do |format|
        format.html { render :show }
        format.json { render json: { article: @article.to_hash } }
      end
    else
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'Article not found' }
        format.json { render json: { errors: ['Article not found'] }, status: :not_found }
      end
    end
  end

  def new
    @article = Article.new
  end

  def create
    @article = Article.new(article_params)
    @article.author_id = current_user.id
    @article.slug = @article.generate_slug(@article.title)
    @article.created_at ||= Time.now
    @article.updated_at ||= Time.now

    respond_to do |format|
      if @article.save
        format.html { redirect_to article_path(@article.slug), notice: 'Article created successfully.' }
        format.json { render json: { article: @article.to_hash }, status: :created }
      else
        format.html do
          flash.now[:alert] = 'There were errors saving your article.'
          render :new
        end
        format.json { render json: { errors: @article.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @article = Article.find_by_slug(params[:id])

    respond_to do |format|
      if @article.author_id != current_user.id
        format.html { redirect_to article_path(@article.slug), alert: 'You are not authorized to edit this article.' }
        format.json { render json: { errors: ['You are not authorized to edit this article.'] }, status: :forbidden }
      else
        format.html
        format.json { render json: { article: @article.to_hash } }
      end
    end
  end

  def update
    article = current_user.find_article_by_slug(params[:id])

    respond_to do |format|
      if article&.update(article_params)
        format.html { redirect_to article_path(article.slug), notice: 'Article updated successfully.' }
        format.json { render json: { article: article.to_hash }, status: :ok }
      else
        format.html { redirect_to root_path, alert: 'There were errors updating your article.' }
        format.json { render json: { errors: article.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    article = Article.find_by_slug(params[:id])

    respond_to do |format|
      if article && article.author_id == current_user.id
        article.destroy
        format.html { redirect_to articles_path, notice: 'Article deleted successfully.' }
        format.json { head :no_content }
      else
        format.html { redirect_to article_path(article.slug), alert: 'You are not authorized to delete this article.' }
        format.json { render json: { errors: ['You are not authorized to delete this article.'] }, status: :forbidden }
      end
    end
  end

  def feed
    articles = current_user.feed
    render json: { articles: articles.map(&:to_hash), articlesCount: articles.count }
  end

  def favorite
    article = Article.find_by_slug(params[:id])

    if article.nil?
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'Article not found' }
        format.json { render json: { errors: ['Article not found'] }, status: :not_found }
      end
      return
    end

    if current_user.favorited?(article)
      respond_to do |format|
        format.html { redirect_to appropriate_path(article.slug), alert: 'Article already favorited.' }
        format.json { render json: { errors: ['Article already favorited'] }, status: :unprocessable_entity }
      end
      return
    end

    current_user.favorite(article)

    respond_to do |format|
      format.html { redirect_to appropriate_path(article.slug), notice: 'Article favorited successfully.' }
      format.json { render json: { article: article.to_hash } }
      format.turbo_stream
    end
  end

  def unfavorite
    article = Article.find_by_slug(params[:id])

    if article.nil?
      respond_to do |format|
        format.html { redirect_to root_path, alert: 'Article not found' }
        format.json { render json: { errors: ['Article not found'] }, status: :not_found }
      end
      return
    end

    unless current_user.favorited?(article)
      respond_to do |format|
        format.html { redirect_to appropriate_path(article.slug), alert: 'Article not favorited.' }
        format.json { render json: { errors: ['Article not favorited'] }, status: :unprocessable_entity }
      end
      return
    end

    current_user.unfavorite(article)

    respond_to do |format|
      format.html { redirect_to appropriate_path(article.slug), notice: 'Article unfavorited successfully.' }
      format.json { render json: { article: article.to_hash } }
      format.turbo_stream
    end
  end

  private

  def article_params
    params.require(:article).permit(:title, :description, :body, :tag_list, :favorites_count)
  end

  def appropriate_path(article)
    if request.referer && URI(request.referer).path == root_path
      root_path
    else
      article_path(article)
    end
  end

  def set_articles_based_on_feed
    @articles = if params[:feed] == 'your' && logged_in?
                  current_user.feed.map do |article|
                    { article:, favorited: current_user.favorited?(article), global: false }
                  end
                else
                  Article.all.map do |article|
                    { article:, favorited: current_user&.favorited?(article), global: true }
                  end
                end
  end
end
