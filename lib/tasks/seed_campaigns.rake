namespace :db do
  namespace :seed do
    desc "Seed demo campaigns + invites so scope-application screenshots look real (idempotent)"
    task campaigns: :environment do
      abort "refuse to run in production" if Rails.env.production?

      shop = Shop.find_by(slug: "tikedon-hq")
      abort "Tikedon HQ shop not found — run `bin/rails db:seed` first" unless shop
      abort "Run `bin/rails db:seed:products` first"        if shop.products.empty?
      abort "Run `bin/rails db:seed:creators` first"        if Creator.count.zero?

      Current.shop = shop

      product_by_sku = shop.products.index_by(&:external_id)
      p = ->(sku) { product_by_sku.fetch(sku) { abort "missing product #{sku}" } }

      campaigns = [
        {
          name: "Summer Collagen Creator Push",
          product: p["sku_collagen_250g"],
          commission_rate: 0.20,
          sample_offer: true,
          status: "active",
          personalize_per_creator: true,
          message_template: "Hey {{creator.handle}} — love your {{creator.top_category}} content! We're {{shop.name}} and we'd love to send you a free jar of {{product.name}} for our summer creator push. {{campaign.commission_pct}} commission on every sale through your showcase. Interested?",
          follow_up_template: "Hey {{creator.handle}}, just checking in — your {{product.name}} sample should've arrived. Let us know when you've posted so we can amplify!",
          notes: "Summer 2026 push. Target creators 50k+ followers in wellness/fitness.",
          invite_mix: { sent: 8, accepted: 5, pending: 3, declined: 2, failed: 1 }
        },
        {
          name: "Ashwagandha Stress Relief Rollout",
          product: p["sku_ashwa_60"],
          commission_rate: 0.15,
          sample_offer: true,
          status: "active",
          personalize_per_creator: false,
          message_template: "Hi {{creator.handle}}! {{shop.name}} here. We're launching {{product.name}} and looking for creators like you to try a free bottle and share your experience. {{campaign.commission_pct}} affiliate commission. Reply if you're in!",
          follow_up_template: "Hi {{creator.handle}}, hope the {{product.name}} is working well for you. When you post, drop the Spark Code in DMs so we can boost the video.",
          notes: "Evergreen campaign. Broad targeting across wellness, mindfulness, productivity categories.",
          invite_mix: { sent: 6, accepted: 3, pending: 2, declined: 1, expired: 1 }
        },
        {
          name: "Hydration Mix Launch — Q2",
          product: p["sku_lyte_30pk"],
          commission_rate: 0.25,
          sample_offer: false,
          status: "paused",
          personalize_per_creator: false,
          message_template: "Hey {{creator.handle}}! We're {{shop.name}} and we loved your recent {{creator.top_category}} videos. Would you like to promote {{product.name}} for {{campaign.commission_pct}} commission? No sample this round — affiliate-link only.",
          follow_up_template: nil,
          notes: "Paused while we source more inventory. Unpause week of 2026-05-05.",
          invite_mix: { sent: 4, declined: 2, failed: 1, pending: 1 }
        },
        {
          name: "Magnesium Sleep Reach",
          product: p["sku_mag_gly_120"],
          commission_rate: 0.18,
          sample_offer: true,
          status: "draft",
          personalize_per_creator: true,
          message_template: "Hi {{creator.handle}} — we noticed your sleep/wellness content. {{shop.name}} would love to send you {{product.name}} plus a {{campaign.commission_pct}} affiliate deal. Interested?",
          follow_up_template: nil,
          notes: "Drafting. Need to finalize creator shortlist before activating.",
          invite_mix: {}
        },
        {
          name: "Vitamin C Glow (Archived)",
          product: p["sku_vitc_30ml"],
          commission_rate: 0.12,
          sample_offer: true,
          status: "ended",
          personalize_per_creator: false,
          message_template: "Hi {{creator.handle}}! {{shop.name}} here. Want to try {{product.name}} and earn {{campaign.commission_pct}} on sales?",
          follow_up_template: nil,
          notes: "Q1 2026 campaign — concluded 2026-03-31. Kept for historical reference.",
          invite_mix: { accepted: 7, declined: 3, expired: 2 }
        }
      ]

      created_campaigns = 0
      created_invites = 0

      # Round-robin a pool of creators so each campaign uses distinct-ish creators.
      creator_pool = Creator.order(:id).limit(250).pluck(:id)
      creator_cursor = 0

      campaigns.each do |attrs|
        invite_mix = attrs.delete(:invite_mix)

        campaign = shop.campaigns.find_or_initialize_by(name: attrs[:name])
        next if campaign.persisted? && campaign.invites.any? # already seeded

        # Create draft first (status validations are lenient on create), then
        # transition so we exercise the real transition path in testing.
        target_status = attrs.delete(:status)
        campaign.assign_attributes(attrs.merge(status: "draft"))
        campaign.save!
        created_campaigns += 1

        # Skip auto-TAP-publish side effect by updating the column directly.
        campaign.update_columns(status: target_status) if target_status != "draft"

        invite_mix.each do |status, count|
          count.times do
            creator_id = creator_pool[creator_cursor % creator_pool.size]
            creator_cursor += 1

            # Respect the unique (creator_id, campaign_id) constraint.
            next if campaign.invites.exists?(creator_id: creator_id)

            creator = Creator.find(creator_id)
            message = Messaging::TemplateRenderer.render(
              campaign.message_template,
              creator: creator, campaign: campaign, shop: shop, product: campaign.product
            )

            sent_at      = %w[sent accepted declined expired].include?(status.to_s) ? rand(1..21).days.ago : nil
            responded_at = %w[accepted declined].include?(status.to_s) ? sent_at + rand(1..72).hours : nil

            Invite.create!(
              creator: creator,
              campaign: campaign,
              shop: shop,
              status: status.to_s,
              message: message,
              sent_at: sent_at,
              responded_at: responded_at,
              error_message: status.to_s == "failed" ? "Creator inbox closed to new conversations" : nil
            )
            created_invites += 1
          end
        end
      end

      # Seed Samples for accepted invites on campaigns that offer samples, so
      # the Samples screen demonstrates `Seller Review Sample Applications`.
      sample_statuses = %i[requested approved shipped delivered follow_up_sent spark_code_received no_response]
      eligible_invites = shop.invites
                             .where(status: "accepted")
                             .joins(:campaign).where(campaigns: { sample_offer: true })
      created_samples = 0
      eligible_invites.each_with_index do |invite, i|
        next if invite.sample.present?

        status = sample_statuses[i % sample_statuses.size].to_s
        attrs = { shop: shop, invite: invite, status: status, max_follow_ups: 3 }

        case status
        when "shipped"
          attrs.merge!(tracking_number: "1Z#{SecureRandom.hex(5).upcase}", shipped_at: rand(1..5).days.ago)
        when "delivered"
          attrs.merge!(tracking_number: "1Z#{SecureRandom.hex(5).upcase}", shipped_at: 7.days.ago, delivered_at: rand(1..3).days.ago)
        when "follow_up_sent"
          attrs.merge!(tracking_number: "1Z#{SecureRandom.hex(5).upcase}", shipped_at: 14.days.ago, delivered_at: 10.days.ago,
                       follow_up_count: 1, last_follow_up_message: "Hey, hope the product arrived!", next_follow_up_at: 3.days.from_now)
        when "spark_code_received"
          attrs.merge!(tracking_number: "1Z#{SecureRandom.hex(5).upcase}", shipped_at: 20.days.ago, delivered_at: 16.days.ago,
                       follow_up_count: 1, spark_code: SecureRandom.hex(8).upcase, spark_code_received_at: 2.days.ago)
        when "no_response"
          attrs.merge!(tracking_number: "1Z#{SecureRandom.hex(5).upcase}", shipped_at: 30.days.ago, delivered_at: 25.days.ago, follow_up_count: 3)
        end

        Sample.create!(attrs)
        created_samples += 1
      end

      puts "campaigns: created=#{created_campaigns}, total=#{shop.campaigns.count}"
      puts "invites:   created=#{created_invites}, total=#{shop.invites.count}"
      puts "samples:   created=#{created_samples}, total=#{shop.samples.count}"
      puts "invite status breakdown: #{shop.invites.group(:status).count}"
      puts "sample status breakdown: #{shop.samples.group(:status).count}"
    ensure
      Current.reset
    end
  end
end
