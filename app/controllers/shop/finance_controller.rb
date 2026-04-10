class Shop::FinanceController < Shop::BaseController
  before_action :require_tiktok_connection!
  before_action :build_finance_client

  # GET /shop/finance
  # Overview: recent payments + statements summary
  def show
    authorize!(:show, Finance)

    default_end   = Date.today.iso8601
    default_start = 30.days.ago.to_date.iso8601

    payments_resp   = @finance.payments(start_date: default_start, end_date: default_end, page_size: 5)
    statements_resp = @finance.statements(start_date: default_start, end_date: default_end, page_size: 5)

    @recent_payments   = payments_resp.dig("data", "payments")   || []
    @recent_statements = statements_resp.dig("data", "statements") || []
  rescue Tiktok::Error => e
    @tiktok_error = e.message
    @recent_payments   = []
    @recent_statements = []
  end

  # GET /shop/finance/payments
  def payments
    authorize!(:payments, Finance)

    @start_date = params[:start_date].presence || 30.days.ago.to_date.iso8601
    @end_date   = params[:end_date].presence   || Date.today.iso8601

    resp = @finance.payments(start_date: @start_date, end_date: @end_date, page_size: 50,
                             page_token: params[:page_token])
    @payments        = resp.dig("data", "payments")   || []
    @next_page_token = resp.dig("data", "next_page_token")
  rescue Tiktok::Error => e
    @tiktok_error = e.message
    @payments     = []
  end

  # GET /shop/finance/statements
  def statements
    authorize!(:statements, Finance)

    @start_date     = params[:start_date].presence
    @end_date       = params[:end_date].presence
    @payment_status = params[:payment_status].presence

    resp = @finance.statements(
      start_date: @start_date, end_date: @end_date,
      payment_status: @payment_status, page_size: 50,
      page_token: params[:page_token]
    )
    @statements      = resp.dig("data", "statements") || []
    @next_page_token = resp.dig("data", "next_page_token")
  rescue Tiktok::Error => e
    @tiktok_error = e.message
    @statements   = []
  end

  # GET /shop/finance/transactions
  def transactions
    authorize!(:transactions, Finance)

    @mode         = params[:mode].presence_in(%w[order statement unsettled]) || "order"
    @start_date   = params[:start_date].presence || 30.days.ago.to_date.iso8601
    @end_date     = params[:end_date].presence   || Date.today.iso8601
    @statement_id = params[:statement_id].presence

    resp = case @mode
           when "statement"
             if @statement_id.present?
               @finance.transactions_by_statement(statement_id: @statement_id, page_size: 50,
                                                  page_token: params[:page_token])
             else
               { "data" => {} }
             end
           when "unsettled"
             @finance.unsettled_transactions(page_size: 50, page_token: params[:page_token])
           else
             @finance.transactions_by_order(start_date: @start_date, end_date: @end_date,
                                            page_size: 50, page_token: params[:page_token])
           end

    @transactions    = resp.dig("data", "transactions") || []
    @next_page_token = resp.dig("data", "next_page_token")
  rescue Tiktok::Error => e
    @tiktok_error    = e.message
    @transactions    = []
  end

  private

  def require_tiktok_connection!
    unless Current.shop.tiktok_connected?
      redirect_to shop_tiktok_connection_path, alert: "Connect your TikTok Shop to access Finance data."
    end
  end

  def build_finance_client
    token = Current.shop.tiktok_token
    @finance = Tiktok::Resources::Finance.new(
      token: token.access_token,
      shop_cipher: token.shop_cipher
    )
  end
end
