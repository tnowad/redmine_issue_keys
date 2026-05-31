# frozen_string_literal: true

module RedmineIssueKeys
  module ProjectPatch
    extend ActiveSupport::Concern

    prepended do
      safe_attributes 'issue_key_prefix',
                      if: lambda {|project, user| user.allowed_to?(:edit_project, project)}
      alias_attribute :prefix, :issue_key_prefix
      validate :issue_key_prefix_format
      validate :issue_key_prefix_uniqueness
      before_validation :normalize_issue_key_prefix
    end

    def normalize_issue_key_prefix
      self.issue_key_prefix = issue_key_prefix.to_s.upcase.presence
    end

    def issue_key_prefix_format
      return if issue_key_prefix.blank?
      return if issue_key_prefix.match?(/\A[A-Z][A-Z0-9]{1,15}\z/)

      errors.add(:prefix, :invalid)
    end

    def issue_key_prefix_uniqueness
      return if issue_key_prefix.blank?
      return unless Project.where(issue_key_prefix: issue_key_prefix).where.not(id: id).exists?

      errors.add(:prefix, :taken)
    end
  end
end
