require 'test_helper'

class YarnsControllerTest < ActionController::TestCase
  setup do
    @yarn = yarns(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:yarns)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create yarn" do
    assert_difference('Yarn.count') do
      post :create, :yarn => @yarn.attributes
    end

    assert_redirected_to yarn_path(assigns(:yarn))
  end

  test "should show yarn" do
    get :show, :id => @yarn.to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => @yarn.to_param
    assert_response :success
  end

  test "should update yarn" do
    put :update, :id => @yarn.to_param, :yarn => @yarn.attributes
    assert_redirected_to yarn_path(assigns(:yarn))
  end

  test "should destroy yarn" do
    assert_difference('Yarn.count', -1) do
      delete :destroy, :id => @yarn.to_param
    end

    assert_redirected_to yarns_path
  end
end
