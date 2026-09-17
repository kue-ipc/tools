# frozen_string_literal: true

# Ansible Playbook
# v0.1.2
#
# Copyright 2023-2025 Kyoto University of Eductaion
# Released under the MIT License
# https://opensource.org/licenses/MIT
#
# Compitable: Ruby 3.0 or higher

require_relative "../lib/run_and_mail"

class AnsiblePlaybook < RunAndMail
  def initialize(ansible_playbook: "ansible-playbook", ansible_dir: Dir.pwd,
      out_omit: [:ok, :skipping], pre: nil, post: nil, **opts)
    super(**opts)
    @ansible_playbook = ansible_playbook
    @ansible_dir = ansible_dir
    @out_omit = out_omit
    @pre = pre
    @post = post
  end

  # TODO: support json format output
  #   set {"ANSIBLE_STDOUT_CALLBACK" => "json"} on first arg and parse output
  def playbook(playbooks, check: false, limit: nil, extra_vars: [], **opts)
    cmd_list = []
    cmd_list << [@ansible_playbook, *@pre] if @pre&.size&.positive?
    cmd_list << create_cmd(playbooks, check: check, limit: limit,
      extra_vars: extra_vars)
    cmd_list << [@ansible_playbook, *@post] if @post&.size&.positive?

    result = run_cat(*cmd_list, chdir: @ansible_dir, **opts)
    result.info_concat(playbooks.join(" "))
    result.info_concat(" (C)") if check
    result.info_concat(" [#{limit}]") if limit
    result.info_concat(" #{extra_vars.join(' ')}") unless extra_vars.empty?
    @out_omit&.each { |name| result.out_omit(/^#{name}: \[/) }

    mail(result)
    result
  rescue => e
    @logger.error e.full_message(highlight: false, order: :top)
    raise
  end

  private def create_cmd(playbooks, check: false, limit: nil, extra_vars: [])
    cmd = []
    cmd << @ansible_playbook
    cmd << "--check" if check
    cmd << "--limit" << limit if limit
    extra_vars.each do |var|
      cmd << "--extra_vars" << var
    end
    cmd.concat(playbooks)
    cmd
  end
end
