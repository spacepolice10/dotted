namespace :bookmarks do
  desc 'Download favicons for bookmarks saved before favicon attachments were added'
  task backfill_favicons: :environment do
    Bookmark.where.not(icon_link: [nil, '']).where.missing(:favicon_attachment).find_each do |bookmark|
      Bookmark::UnfurlJob.perform_now(bookmark)
    end
  end
end
