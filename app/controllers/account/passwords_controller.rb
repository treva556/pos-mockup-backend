module Account
  class PasswordsController < ApplicationController
    before_action :authenticate_user!

    def edit
      @errors = []
    end

    def update
      @errors = []

      unless current_user.authenticate(
        password_params[:current_password]
      )
        @errors << "Current password is incorrect."

        render :edit, status: :unprocessable_entity
        return
      end

      if current_user.update(
        password: password_params[:password],
        password_confirmation:
          password_params[:password_confirmation],
        must_change_password: false
      )
        redirect_to after_login_path,
                    notice: "Your password was changed."
      else
        @errors = current_user.errors.full_messages

        render :edit, status: :unprocessable_entity
      end
    end

    private

    def password_params
      params.require(:password_change).permit(
        :current_password,
        :password,
        :password_confirmation
      )
    end
  end
end