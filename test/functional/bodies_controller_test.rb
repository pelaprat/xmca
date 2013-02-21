require 'test_helper'

class BodiesControllerTest < ActionController::TestCase
  setup do
    @body = bodies(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:bodies)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create body" do
    assert_difference('Body.count') do
      post :create, :body => @body.attributes
    end

    assert_redirected_to body_path(assigns(:body))
  end

  test "should show body" do
    get :show, :id => @body.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @body.to_param
    assert_response :success
  end

  test "should update body" do
    put :update, :id => @body.to_param, :body => @body.attributes
    assert_redirected_to body_path(assigns(:body))
  end

  test "should destroy body" do
    assert_difference('Body.count', -1) do
      delete :destroy, :id => @body.to_param
    end

    assert_redirected_to bodies_path
  end
end
