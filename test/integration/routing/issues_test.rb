# frozen_string_literal: true

require_relative '../../test_helper'

module RedmineIssueKeys
  class RoutingIssuesTest < Redmine::RoutingTest
    def test_browse_issue_key_routes
      should_route 'GET /browse/AUTH-1' => 'issues#show', :issue_key => 'AUTH-1'
      should_route 'GET /browse/auth-1' => 'issues#show', :issue_key => 'auth-1'
      should_route 'GET /issues/AUTH-1' => 'issues#show', :id => 'AUTH-1'
      should_route 'GET /issues/1' => 'issues#show', :id => '1'
    end
  end
end
