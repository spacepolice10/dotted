# frozen_string_literal: true

require 'test_helper'

class TimelineSectionsTest < ActionView::TestCase
  setup do
    @user = users(:one)
    @timeline = Timeline.new(@user)
  end

  test 'renders each bullet through the bullet partial the caller supplies' do
    create_bullet!(@user, body: 'Anchor line', pops_on: Date.current)

    html = render partial: 'bullets/timeline_sections',
                  locals: { bullets: @user.bullets, timeline: @timeline, bullet_partial: 'bullets/current_bullet' }

    assert_select fragment(html), 'div#timeline_section_current_date .bullet--current', count: 1
  end

  test 'falls back to the bullet partial' do
    create_bullet!(@user, body: 'Plain line', pops_on: Date.current)

    html = render partial: 'bullets/timeline_sections', locals: { bullets: @user.bullets, timeline: @timeline }

    assert_select fragment(html), 'div#timeline_section_current_date > turbo-frame.bullet', count: 1
  end

  test 'does not mount an empty today append target' do
    create_bullet!(@user, body: 'Old line', pops_on: Date.current - 1)

    html = render partial: 'bullets/timeline_sections', locals: { bullets: @user.bullets, timeline: @timeline }
    fragment = fragment(html)

    assert_select fragment, 'div#timeline_section_current_date', count: 0
    assert_equal 'timeline_section_yesterday', fragment.css('.timeline--section').last['id']
  end

  test 'ensures one empty current date section after older bullets' do
    create_bullet!(@user, body: 'Old line', pops_on: Date.current - 1)

    html = render partial: 'bullets/timeline_sections',
                  locals: { bullets: @user.bullets.by_date, timeline: @timeline, ensure_current_date: true }
    sections = fragment(html).css('.timeline--section')

    assert_equal %w[timeline_section_yesterday timeline_section_current_date], sections.map { |section| section['id'] }
    assert_equal 0, sections.last.css('.bullet').size
  end

  test 'ensured current date section precedes future bullets' do
    create_bullet!(@user, body: 'Future line', pops_on: Date.current + 1)

    html = render partial: 'bullets/timeline_sections',
                  locals: { bullets: @user.bullets.by_date, timeline: @timeline, ensure_current_date: true }
    sections = fragment(html).css('.timeline--section')

    assert_equal 'timeline_section_current_date', sections.first['id']
    assert_equal 1, sections.last.css('.bullet').size
  end

  private

  def fragment(html)
    Nokogiri::HTML5.fragment(html)
  end
end
