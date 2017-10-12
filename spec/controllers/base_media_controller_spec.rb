require 'rails_helper'

RSpec.describe BaseMediaController, type: :controller do
  controller do
    def anything
      render nothing: true
    end
  end

  before do
    routes.draw do
      get 'anything' => 'base_media#anything'
    end
  end

  it 'does not require sign-in permission' do
    expect(controller).not_to receive(:require_signin_permission!)

    get :anything
  end
end
