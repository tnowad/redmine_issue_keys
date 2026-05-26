# frozen_string_literal: true

class ProjectIssueCounter < ApplicationRecord
  self.table_name = 'project_issue_counters'

  belongs_to :project

  validates :project_id, presence: true, uniqueness: true
  validates :next_value, presence: true, numericality: {only_integer: true, greater_than: 0}
end
