defmodule Common do

  # :calendar.datetime_to_gregorian_seconds({{1970,1,1},{0,0,0}})
  @epoch_ref_gregorian 62167219200
  
  def epoch_to_datetime(nil), do: :error
  def epoch_to_datetime(epoch) when is_integer(epoch), do: :calendar.gregorian_seconds_to_datetime(@epoch_ref_gregorian + epoch)
  def epoch_to_datetime(epoch) when is_list(epoch) do
    case Integer.parse(epoch) do
      :error -> :error
      int    -> epoch_to_datetime(int)
    end
  end

  def epoch_to_string(epoch) do
    case epoch_to_datetime(epoch) do
      :error             -> ""
      {{y,m,d},{h,mi,s}} -> "#{y}-#{rjust(m)}-#{rjust(d)} #{rjust(h)}:#{rjust(mi)}:#{rjust(s)}"
    end
  end

  defp rjust(i) do
    i
    |> Integer.to_string
    |> String.rjust(2, ?0)
  end
  
end
