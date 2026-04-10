namespace :db do
  namespace :seed do
    desc "Generate ~200 fake Creator records for UI development (idempotent)"
    task creators: :environment do
      abort "refuse to run in production" if Rails.env.production?

      handles = %w[
        beautybyamy lipgloss_lily glow_with_gigi skintok_sara serum_queen
        fitness_fox gymrat_jenna lift_with_lina protein_pat hiit_helen
        cookwithcarlos foodtok_finn vegan_violet keto_kaylee bake_with_ben
        plantmom_priya succulent_sam orchid_olivia gardenguru_grace
        wanderwithwes travelblog_tia backpacker_brian roadtrip_rita
        gadgetgary techtok_terry coderkid_kai homestudio_hank
        diy_doris crafty_chloe woodworker_will makerspace_mike
        gamerguy_glenn streamerstacy speedrunsteve cozygamer_cleo
        booktok_belle reader_ria fantasy_flynn poetrypam writer_wade
        dogdad_drew cattok_cara petparent_paige aquariumann
        moneymike_finance budgetbella saversam thrifty_tim
        skater_sky surfslade snowsam climber_kim
        momtok_mia dadtok_dan parentpro homeschoolhayley
        artaria sketchsofia paintwithpax sculptures_sage
        musictok_mason violinviolet drumdana guitarguy_greg
      ]

      categories = [
        %w[beauty skincare],
        %w[beauty makeup],
        %w[beauty haircare],
        %w[fitness],
        %w[fitness wellness],
        %w[food cooking],
        %w[food vegan],
        %w[home garden],
        %w[home diy],
        %w[travel],
        %w[tech gadgets],
        %w[gaming],
        %w[books],
        %w[pets],
        %w[finance],
        %w[parenting],
        %w[art],
        %w[music],
        %w[outdoors sports]
      ]

      countries = %w[US US US US US CA UK AU US US]  # weighted toward US

      tier_buckets = [
        # gmv_cents range, gmv_tier, follower range
        [ 0..1_000_000,            "under_10k",   1_000..15_000 ],
        [ 1_000_000..10_000_000,    "10k_100k",    15_000..80_000 ],
        [ 10_000_000..50_000_000,   "100k_500k",   80_000..400_000 ],
        [ 50_000_000..500_000_000,  "500k_plus",   400_000..2_500_000 ]
      ]

      created = 0
      updated = 0

      handles.each_with_index do |handle, i|
        bucket = tier_buckets.sample
        gmv_cents = rand(bucket[0])
        gmv_tier = bucket[1]
        follower_count = rand(bucket[2])
        avg_views = (follower_count * (0.05 + rand * 0.15)).to_i
        engagement = (0.02 + rand * 0.08).round(4)
        cats = categories.sample
        country = countries.sample

        creator = Creator.find_or_initialize_by(external_id: "fake_#{handle}")
        was_new = creator.new_record?
        creator.assign_attributes(
          handle: handle,
          display_name: handle.split("_").map(&:capitalize).join(" "),
          avatar_url: "https://i.pravatar.cc/120?u=#{handle}",
          follower_count: follower_count,
          avg_views: avg_views,
          engagement_rate: engagement,
          gmv_cents: gmv_cents,
          gmv_tier: gmv_tier,
          country: country,
          categories: cats,
          last_seen_at: Time.current,
          raw: { fake: true, seed_version: 1 }
        )
        creator.save!
        was_new ? created += 1 : updated += 1
      end

      # Generate variants of the same handles to reach ~200 records
      4.times do |round|
        handles.each do |base|
          handle = "#{base}_#{round}"
          bucket = tier_buckets.sample
          Creator.find_or_create_by!(external_id: "fake_#{handle}") do |c|
            c.handle = handle
            c.display_name = handle.split("_").map(&:capitalize).join(" ")
            c.avatar_url = "https://i.pravatar.cc/120?u=#{handle}"
            c.follower_count = rand(bucket[2])
            c.avg_views = (c.follower_count * (0.05 + rand * 0.15)).to_i
            c.engagement_rate = (0.02 + rand * 0.08).round(4)
            c.gmv_cents = rand(bucket[0])
            c.gmv_tier = bucket[1]
            c.country = countries.sample
            c.categories = categories.sample
            c.last_seen_at = Time.current
            c.raw = { fake: true, seed_version: 1 }
            created += 1
          end
        end
      end

      total = Creator.count
      puts "creators: created=#{created}, updated=#{updated}, total=#{total}"
    end
  end
end
