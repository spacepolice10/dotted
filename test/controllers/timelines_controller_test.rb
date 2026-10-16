# frozen_string_literal: true

require 'test_helper'

class TimelinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test 'root is the daylog' do
    get root_path

    assert_response :success
    assert_select '#timeline.timeline--scroller[data-controller~="timeline-scroll"]'
  end

  test 'index mounts a hidden today section for the composer' do
    get bullets_path

    assert_response :success
    assert_select '#timeline_section_current_date'
    assert_select '#composer_dock input[name="bullet[file]"][type="file"]'
    assert_select '#timeline_composer_dock input[name="bullet[bulletable_type]"]', count: 0
    assert_select '.timeline--load-more-trigger', count: 0
  end

  test 'index loads the latest day and pages back one day at a time' do
    today = create_bullet!(@user, body: 'Today line')
    yesterday = create_bullet!(@user, body: 'Yesterday line', pops_on: Date.current - 1)
    create_bullet!(@user, body: 'Ancient line', pops_on: Date.current - 20)

    get bullets_path

    assert_select '#timeline_section_current_date .bullet', text: /Today line/
    assert_no_match 'Yesterday line', response.body
    assert_select '.timeline--load-more-trigger'

    get bullets_path(before: today.id)
    assert_select "#timeline_section_#{yesterday.pops_on.iso8601} .bullet", text: /Yesterday line/
    assert_no_match 'Ancient line', response.body

    get bullets_path(before: yesterday.id)
    assert_select '.timeline--section .bullet', text: /Ancient line/
  end

  test 'older days show their date and separate years' do
    travel_to Date.new(2026, 9, 30) do
      recent = create_bullet!(@user, body: 'Late August', pops_on: Date.new(2026, 8, 29))
      older = create_bullet!(@user, body: 'Early August', pops_on: Date.new(2026, 8, 1))
      create_bullet!(@user, body: 'Previous August', pops_on: Date.new(2025, 8, 15))

      get bullets_path
      assert_select '#timeline_section_2026-08-29 h2.pill', text: 'Saturday, Aug 29'

      get bullets_path(before: recent.id)
      assert_select '.timeline--section h2.pill', text: 'Saturday, Aug 1'

      get bullets_path(before: older.id)
      assert_select '.timeline--section h2.pill', text: 'Friday, Aug 15, 2025'
    end
  end

  test 'rows within a day read oldest first' do
    create_bullet!(@user, body: 'Earlier', created_at: 2.hours.ago)
    create_bullet!(@user, body: 'Later', created_at: 1.hour.ago)

    get bullets_path

    assert_operator response.body.index('Earlier'), :<, response.body.index('Later')
  end

  test 'index hides upcoming and completed bullets and keeps tagged ones' do
    create_bullet!(@user, body: 'Future line', pops_on: Date.current + 3)
    create_bullet!(@user, body: 'Filed line', collection: create_collection!(@user, name: 'Work'))
    create_bullet!(@user, body: 'Gone line').complete!

    get bullets_path

    assert_no_match 'Future line', response.body
    assert_match 'Filed line', response.body
    assert_no_match 'Gone line', response.body
  end

  test 'a date over 50 shows an explicit button for its remaining bullets' do
    Array.new(Bullet::Pageable::PAGE_SIZE + 1) { |i| create_bullet!(@user, body: "Line #{i}", created_at: (100 - i).minutes.ago) }

    get bullets_path

    assert_select '.timeline--load-more-trigger', count: 0
    assert_select '.timeline--section-header a[href=?]', bullets_path(from: Date.current.iso8601, to: Date.current.iso8601), text: 'Show all bullets'
    assert_select '#timeline .bullet', count: Bullet::Pageable::PAGE_SIZE
  end

  test 'a timeline filtered to one date loads every matching bullet' do
    date = Date.current - 1
    (Bullet::Pageable::PAGE_SIZE + 5).times do |index|
      create_bullet!(@user, body: "On date #{index}", pops_on: date)
    end
    create_bullet!(@user, body: 'Other date')

    get bullets_path(from: date.iso8601, to: date.iso8601)

    assert_select '#timeline .bullet', count: Bullet::Pageable::PAGE_SIZE + 5
    assert_select '.timeline--section-header a', text: 'Show all bullets', count: 0
    assert_select '.timeline--load-more-trigger', count: 0
    assert_no_match 'Other date', response.body
  end

  test 'show all link keeps the collection filter' do
    collection = create_collection!(@user, name: 'Work')
    (Bullet::Pageable::PAGE_SIZE + 1).times do |index|
      create_bullet!(@user, body: "Work #{index}", collection: collection)
    end

    get bullets_path(collection: collection.name)

    assert_select '.timeline--section-header a[href=?]',
                  bullets_path(collection: collection.name, from: Date.current.iso8601, to: Date.current.iso8601),
                  text: 'Show all bullets'
  end

  test 'requires authentication' do
    sign_out

    get bullets_path

    assert_redirected_to new_authentication_path
  end
end
