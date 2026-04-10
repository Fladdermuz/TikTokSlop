# AJAX endpoint for the campaign editor's "Run AI check" button.
# Scans arbitrary text through the full Moderation::Scanner pipeline and
# renders a Turbo Frame with the result.
#
# Does NOT persist anything — this is ephemeral preview for the editor.
# Persistence happens when the campaign is saved and at send time.
class Shop::ModerationPreviewsController < Shop::BaseController
  def create
    text = params[:text].to_s
    @result = if text.blank?
      Moderation::Result.empty
    else
      Moderation::Scanner.scan(text, shop: Current.shop)
    end

    render partial: "result", locals: { result: @result }
  end
end
