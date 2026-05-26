# frozen_string_literal: true

module RedmineIssueKeys
  module ApplicationControllerPatch
    def find_issue
      if params[:issue_key].present? || params[:id].to_s.match?(/\A[A-Z][A-Z0-9]{1,15}-\d+\z/i)
        @issue = Issue.find_by_issue_key(params[:issue_key].presence || params[:id])
        return render_404 unless @issue
        raise Unauthorized unless @issue.visible?
        @project = @issue.project
      else
        super
      end
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end
