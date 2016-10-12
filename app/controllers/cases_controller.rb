class CasesController < ApplicationController
  before_action :find_case, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :show, :history, :followers]

  def new
    @case = current_user.cases.build
    @case.agencies.build
  end

  def index
    page_size = 12
    @cases = Case.by_state(params[:state_id]).search(params[:query], page: params[:page], per_page: page_size) if params[:query].present? && params[:state_id].present?
    @cases = Case.by_state(params[:state_id]).order('date DESC').page(params[:page]).per(page_size) if !params[:query].present? && params[:state_id].present?
    @cases = Case.search(params[:query], page: params[:page], per_page: page_size) if params[:query].present? && !params[:state_id].present?
    @cases = Case.all.order('date DESC').page(params[:page]).per(page_size) if (!params[:query].present? && !params[:state_id].present?)
  end

  def show
    @case = Case.friendly.find(params[:id])
    @commentable = @case
    @comments = @commentable.comments
    @comment = Comment.new
    @subjects = @case.subjects

    # Check to make sure all required elements are here
    unless @case.present? && @case.present?	&& @commentable.present? && @comment.present? &&
        @subjects.present?
      flash[:error] = "There was an error showing this case. Please try again later"
      redirect_to	root_path
    end
  end

  def create
    @case = current_user.cases.build(case_params)
    # This could be a very expensive query as the userbase gets larger.
    # TODO: Create a scope to send only to users who have chosen to receive email updates
    if @case.save
      flash[:success] = "Case was created! #{make_undo_link}"
      redirect_to @case
    else
      render 'new'
    end
  end

  def edit
    @case = Case.friendly.find(params[:id])
    @case.update_attribute(:summary, nil)
  end

  def followers
    @case = Case.friendly.find(params[:id])
  end

  def update
    @case = Case.friendly.find(params[:id])
    @case.slug = nil
    if @case.remove_avatar?
      @case.remove_avatar!
    end
    if @case.update_attributes(case_params)
      flash[:success] = "Case was updated! #{make_undo_link}"
      UserNotifier.send_followers_email(@case.followers,@case).deliver_now
      redirect_to @case
    else
      render 'edit'
    end
  end

  def destroy
    @case.destroy
    flash[:success] = "Case was removed! #{make_undo_link}"
    UserNotifier.notify_of_removal(@case.followers,@case).deliver_now
    redirect_to root_path
  end

  def history
    @case = Case.friendly.find(params[:id])
    @versions = @case.versions.sort_by(&:created_at).reverse
  end

  def undo
    @case_version = PaperTrail::Version.find_by_id(params[:id])

    begin
      if @case_version.reify
        @case_version.reify.save
      else
        # For undoing the create action
        @case_version.item.destroy
      end
      flash[:success] = "Undid that! #{make_redo_link}"
    rescue
      flash[:alert] = "Failed undoing the action..."
    ensure
      redirect_to root_path
    end
  end

  private

  def find_case
    @case = Case.friendly.find(params[:id])
  end

  def make_undo_link
    view_context.link_to 'Undo that please!', undo_path(@case.versions.last), method: :post
  end

  def make_redo_link
    params[:redo] == "true" ? link = "Undo that please!" : link = "Redo that please!"
    view_context.link_to link, undo_path(@case_version.next, redo: !params[:redo]), method: :post
  end

  def case_params
    params.require(:case).permit(:title, :age, :overview, :litigation, :community_action, :agency_id, :category_id, :date, :state_id, :city, :address, :zipcode, :longitude, :latitude, :avatar, :video_url, :remove_avatar, :summary, links_attributes: [:id, :url, :_destroy],  comments_attributes: [:comment, :content, :commentable_id, :commentable_type], subjects_attributes: [:name, :age, :gender_id, :ethnicity_id, :unarmed, :homeless, :veteran, :mentally_ill, :id, :_destroy], agency_ids: [])
  end

  # from the tutorial (https://gorails.com/episodes/comments-with-polymorphic-associations)
  # why did they set commentable here?
  def set_commentable
    @commentable = Case.friendly.find(params[:id])
  end
end
