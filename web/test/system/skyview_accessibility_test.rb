# frozen_string_literal: true

require_relative 'ui_accessibility_test'

# Run the shared keyboard, motion and text-contrast checks against the sky palette.
class SkyviewAccessibilitySystemTest < UiAccessibilitySystemTest
  setup do
    @user.settings!.update!(appearance: 'kazakstans_skyview')
  end
end
