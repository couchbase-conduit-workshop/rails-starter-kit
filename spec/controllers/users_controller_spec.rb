

require 'rails_helper'
require 'jwt'

RSpec.describe UsersController, type: :controller do
  let(:current_user) do
    User.new(id: 'user-id', username: 'testuser', email: 'test@example.com',
             password_digest: BCrypt::Password.create('password'), bio: 'Test bio', image: 'test_image.png')
  end
  let(:article) do
    Article.new(title: 'Test Title', description: 'Test Description', body: 'Test Body', created_at: Time.now,
                updated_at: Time.now, tag_list: %w[tag1 tag2])
  end
  let(:token) { JWT.encode({ user_id: current_user.id }, Rails.application.secret_key_base) }

  before do
    allow(article).to receive(:author).and_return(current_user)
    allow(User).to receive(:new).and_return(current_user)
    allow(User).to receive(:find_by_email).and_return(current_user)
    allow(User).to receive(:find).with(current_user.id).and_return(current_user)
    allow(JWT).to receive(:decode).and_return([{ 'user_id' => current_user.id }])
    request.headers['Authorization'] = "Bearer #{token}"
    session[:user_id] = current_user.id
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      it 'creates a new user and returns the user with a token' do
        allow(current_user).to receive(:save).and_return(true)

        post :create,
             params: { user: { username: 'testuser', email: 'test@example.com', password: 'password', bio: 'Test bio',
                               image: 'test_image.png' } }

        expect(response).to have_http_status(:found)
        expect(flash[:notice]).to eq('User created successfully. Please log in.')
      end
    end

    context 'with invalid parameters' do
      it 'returns an error' do
        allow(current_user).to receive(:save).and_return(false)
        allow(current_user).to receive_message_chain(:errors, :full_messages).and_return(['Error message'])

        post :create,
             params: { user: { username: 'testuser', email: 'test@example.com', password: 'password', bio: 'Test bio',
                               image: 'test_image.png' } }

        expect(response).to have_http_status(:ok)
        expect(flash[:alert])
      end
    end
  end

  describe 'POST #login' do
    context 'with valid credentials' do
      it 'returns the user with a token' do
        password = BCrypt::Password.create('password')
        allow(BCrypt::Password).to receive(:new).with(current_user.password_digest).and_return(password)
        allow(password).to receive(:==).with('password').and_return(true)

        post :login, params: { email: 'test@example.com', password: 'password' }

        expect(response).to have_http_status(:found)
        expect(flash[:notice]).to eq('Logged in successfully')
      end
    end

    context 'with invalid credentials' do
      it 'returns an error' do
        allow(BCrypt::Password).to receive(:new).and_return(BCrypt::Password.create('wrong_password'))

        post :login, params: { user: { email: 'test@example.com', password: 'password' } }

        expect(response).to have_http_status(:ok)
        expect(flash[:error]).to eq('Invalid email or password')
      end
    end
  end

  describe 'GET #show' do
    context 'when authenticated' do
      it 'returns the user profile page' do
        allow(current_user).to receive(:articles).and_return([article])
        get :show

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('testuser')
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        allow(current_user).to receive(:articles).and_return([])
        request.headers['Authorization'] = nil
        session[:user_id] = nil

        get :show

        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('User not found')
      end
    end
  end

  describe 'PUT #update' do
    context 'when authenticated' do
      it 'updates the current user and returns the updated user' do
        allow(current_user).to receive(:update).and_return(true)

        updated_attributes = { username: 'updateduser', bio: 'Updated bio' }

        allow(current_user).to receive(:update).with(updated_attributes.stringify_keys).and_return(true)

        put :update, params: { user: updated_attributes }

        expect(response).to have_http_status(:found)
        expect(response.body).to redirect_to(profile_path(current_user.username))
      end
    end

    context 'when not authenticated' do
      it 'returns an error' do
        request.headers['Authorization'] = nil
        session[:user_id] = nil

        put :update, params: { user: { username: 'updateduser', bio: 'Updated bio' } }

        expect(response).to have_http_status(:found)
        expect(flash[:alert]).to eq('Unable to save')
      end
    end
  end
end
