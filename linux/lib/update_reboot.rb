# frozen_string_literal: true

# Update & Reboot
# v0.1.1
#
# Copyright 2024-2025 Kyoto University of Eductaion
# Released under the MIT License
# https://opensource.org/licenses/MIT
#
# Compitable: Ruby 3.0 or higher

require_relative "../lib/run_and_mail"

class UpdateReboot < RunAndMail
  def initialize(force_reboot: false, reboot_wait: 10, **opts)
    super(err: :out, **opts)
    @force_reboot = force_reboot
    @reboot_wait = reboot_wait

    @pkg_manager =
      if system("which dnf >/dev/null 2>&1")
        :dnf
      elsif system("which apt >/dev/null 2>&1")
        :apt
      elsif system("which pacman >/dev/null 2>&1")
        :pacman
      else
        raise "No supported package manager was found."
      end
  end

  def update_reboot
    @logger.info "update_reboot"
    result = update
    if result.success?
      if !require_reboot
        result.info_concat("update only")
      elsif @reboot_wait.positive?
        result << reboot
        result.info_concat("update and reboot +#{@reboot_wait}")
      else
        @logger.info "reboot at exit"
        at_exit { reboot }
        result.info_concat("update and reboot now")
      end
    end
    mail(result) if @mail
    result
  rescue => e
    @logger.error e.full_message(highlight: false, order: :top)
    raise
  end

  def update
    @logger.info "update"
    case @pkg_manager
    in :dnf
      run_cat("dnf upgrade -q -y")
    in :apt
      run_cat("apt update -q", "apt upgrade -q -y")
    in :pacman
      run_cat("pacman -Syuq --noconfirm")
    end
  end

  def require_reboot
    @logger.info "require_reboot"
    return true if @force_reboot

    case @pkg_manager
    in :dnf
      !system("dnf needs-restarting -r >/dev/null 2>&1")
    in :apt
      FileTest.exist?("/var/run/reboot-required")
    in :pacman
      # TODO: always true, but should check libraries
      # https://unix.stackexchange.com/a/123770
      # sudo lsof +c 0 | grep 'DEL.*lib'
      true
    end
  end

  def reboot
    @logger.info "reboot"
    time =
      if @reboot_wait.positive?
        "+#{@reboot_wait}"
      else
        "now"
      end
    run("shutdown -r #{time}")
  end
end
