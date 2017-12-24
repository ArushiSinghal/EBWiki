# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CommentsController, type: :controller do
  # describe "GET #index" do
  #   it "returns http success" do
  #     get :index
  #     expect(response).to have_http_status(:success)
  #   end
  # end

  # describe "GET #new" do
  #   it "returns http success" do
  #     get :new
  #     expect(response).to have_http_status(:success)
  #   end
  # end
  describe 'Case comments' do
    let(:this_case) { FactoryBot.create(:case) }
    let(:comment) { this_case.comments.create(content: 'a pithy comment') }
    login_user

    subject { comment }

    it { should be_valid }

    it { should respond_to(:content) }
    it { should respond_to(:commentable_type) }
    it { should respond_to(:commentable_id) }

    it 'creates a new comment with valid attributes' do
      comment_attr = attributes_for(:comment)
      this_case = Case.last || create(:case)

      expect do
        post :create, comment: comment_attr, case_id: this_case.id
      end.to change(Comment, :count).by(1)
    end

    it 'deletes comments when associated Case object is destroyed' do
      this_case.save
      comment.save
      this_case.destroy
      expect(Comment.all).not_to include comment
    end
  end
end
