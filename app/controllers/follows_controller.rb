class FollowsController < ApplicationController
  before_action :authenticate_user!
  respond_to :html, :js
  
  def create
    finished(:case_followed)
  	@article = Article.find(params[:article_id])
    current_user.follow(@article)
    redirect_to @article
  end

  def destroy
  	@article = Article.find(params[:article_id])    
    current_user.stop_following(@article)
    redirect_to @article
  end
end
