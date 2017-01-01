defmodule SSD1306 do
  use Application

  def start(_type, _args) do
    {:ok, pid} = children |> Supervisor.start_link(options)
    Enum.each(Application.get_env(:ssd1306, :devices, []), &connect(&1))
    {:ok, pid}
  end

  def connect(%{bus: _, address: _, reset_pin: _}=config) do
    Supervisor.start_child(SSD1306.Supervisor, [config])
  end

  defp children do
    import Supervisor.Spec, warn: false
    [ worker(SSD1306.Device, []) ]
  end

  defp options, do: [strategy: :simple_one_for_one, name: SSD1306.Supervisor]
end
