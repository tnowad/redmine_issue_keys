# frozen_string_literal: true

module RedmineIssueKeys
  module IssuePatch
    extend ActiveSupport::Concern

    prepended do
      before_validation :assign_issue_key, on: :create
      validates :issue_key, uniqueness: {allow_blank: true, case_sensitive: true}
      validates :project_issue_number, uniqueness: {scope: :project_id, allow_blank: true}
      validate :issue_key_immutable_after_create
      validate :project_issue_number_immutable_after_create
    end

    def display_id
      issue_key.presence || "##{id}"
    end

    class_methods do
      def find_by_issue_key(key)
        key = key.to_s.upcase
        return nil unless key.match?(/\A[A-Z][A-Z0-9]{1,15}-\d+\z/)

        find_by(issue_key: key)
      end
    end

    private

    def assign_issue_key
      return if issue_key.present? || project.nil?
      prefix = project.issue_key_prefix.presence
      return if prefix.blank?

      retries = 0
      begin
        self.class.transaction do
          counter = ProjectIssueCounter.lock.find_or_initialize_by(project_id: project_id)
          if counter.new_record?
            max = self.class.where(project_id: project_id).maximum(:project_issue_number).to_i
            counter.next_value = max + 1
          end

          self.project_issue_number ||= counter.next_value
          self.issue_key ||= "#{prefix}-#{project_issue_number}"
          counter.next_value = project_issue_number + 1
          counter.save!
        end
      rescue ActiveRecord::RecordNotUnique
        retries += 1
        self.project_issue_number = nil
        self.issue_key = nil
        retry if retries < 3
        raise
      end
    end

    def issue_key_immutable_after_create
      return unless persisted?
      return unless will_save_change_to_issue_key?

      errors.add(:issue_key, :invalid)
    end

    def project_issue_number_immutable_after_create
      return unless persisted?
      return unless will_save_change_to_project_issue_number?

      errors.add(:project_issue_number, :invalid)
    end
  end
end
