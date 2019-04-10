class SessionsController < Devise::SessionsController
  protected

  def after_sign_in_path_for(user)
    if params[:job].present?
      job_posting = JobPosting.by_slug_or_id(params[:job]).where(session_id: session.id).first
      return new_job_posting_purchase_path(job_posting) if job_posting&.pending?
    end
    helpers.default_dashboard_path(user)
  end

  def after_sign_out_path_for(_user)
    new_user_session_path
  end
end
