defmodule WeChat.Pay.Transactions do
  @moduledoc """
  微信支付 - 交易
  """
  import Jason.Helpers

  def jsapi(client, appid, description, out_trade_no, notify_url, amount, payer) do
    jsapi(
      client,
      json_map(
        appid: appid,
        mchid: client.mch_id(),
        description: description,
        out_trade_no: out_trade_no,
        notify_url: notify_url,
        amount: %{total: amount, currency: "CNY"},
        payer: %{openid: payer}
      )
    )
  end

  def jsapi(client, body) do
    client.post("/v3/pay/transactions/jsapi", body)
  end

  def request_payment_args(client, appid, prepay_id) do
    timestamp = WeChat.Utils.now_unix() |> to_string()
    nonce_str = :crypto.strong_rand_bytes(24) |> Base.encode64()
    package = "prepay_id=#{prepay_id}"

    sign =
      "#{appid}\n#{timestamp}\n#{nonce_str}\n#{package}\n"
      |> :public_key.sign(:sha256, client.private_key())
      |> Base.encode64()

    %{
      "timeStamp" => timestamp,
      "nonceStr" => nonce_str,
      "package" => package,
      "signType" => "RSA",
      "paySign" => sign
    }
  end

  def query_by_out_trade_no(client, out_trade_no) do
    client.get(
      "/v3/pay/transactions/out-trade-no/#{out_trade_no}",
      query: [mchid: client.mch_id()]
    )
  end

  def query_by_id(client, transaction_id) do
    client.get("/v3/pay/transactions/id/#{transaction_id}", query: [mchid: client.mch_id()])
  end

  def close(client, out_trade_no) do
    client.post(
      "/v3/pay/transactions/out-trade-no/#{out_trade_no}/close",
      json_map(mchid: client.mch_id())
    )
  end
end
