defmodule SSD1306.Commands do
  use Bitwise

  @control_register                         0x00
  @data_register                            0x40

  @cmd_set_contrast                         0x81
  @cmd_display_all_on_resume                0xa4
  @cmd_display_all_on                       0xa5
  @cmd_normal_display                       0xa6
  @cmd_invert_display                       0xa7
  @cmd_display_off                          0xae
  @cmd_display_on                           0xaf
  @cmd_set_display_offset                   0xd3
  @cmd_set_com_pins                         0xda
  @cmd_set_vcom_detect                      0xdb
  @cmd_set_display_clock_div                0xd5
  @cmd_set_pre_charge                       0xd9
  @cmd_set_multiplex                        0xa8
  @cmd_set_low_column                       0x00
  @cmd_set_high_column                      0x10
  @cmd_set_start_line                       0x40
  @cmd_set_memory_mode                      0x20
  @cmd_set_column_address                   0x21
  @cmd_set_page_address                     0x22
  @cmd_com_scan_inc                         0xc0
  @cmd_com_scan_dec                         0xc8
  @cmd_set_seg_remap                        0xa0
  @cmd_set_charge_pump                      0x8d
  @cmd_activate_scroll                      0x2f
  @cmd_deactivate_scroll                    0x2e
  @cmd_set_vertical_scroll_area             0xa3
  @cmd_right_horizontal_scroll              0x26
  @cmd_left_horizontal_scroll               0x27
  @cmd_vertical_and_right_horizontal_scroll 0x29
  @cmd_vertical_and_left_horizontal_scroll  0x2a

  @doc """
  Reset the SSD1306 using the GPIO reset pin.
  """
  def reset!(gpio_pid) do
    with :ok <- Gpio.write(gpio_pid, 1),
         :ok <- :timer.sleep(1),
         :ok <- Gpio.write(gpio_pid, 0),
         :ok <- :timer.sleep(10),
         :ok <- Gpio.write(gpio_pid, 1),
         do: :ok
  end

  @doc """
  Initialize the device using "sane defaults" based on the display size.

  Configurable options (configure by adding these keys to your device's keys
  in your application configuration) and their defaults below:

      config :ssd1306,
        device: [%{
          display_clock_div: 0x80,
          multiplex: 0x3f,
          external_vcc: false,
          charge_pump: 0x10, # or 0x14 if :external_vcc is true
          memory_mode: 0x80,
          segment_remap: 0x01,
          com_pins: 0x12,
          contrast: 0x9f, # or 0xcf if :external_vcc is true
          pre_charge: 0x22, # or 0xf1 if :external_vcc is true
          vcom_detect: 0x40
        }]
  """
  def initialize!(%{i2c: pid}=state) do
    with :ok <- display_off!(pid),
         :ok <- display_clock_div(pid, Map.get(state, :display_clock_div, 0x80)),
         :ok <- multiplex(pid, Map.get(state, :multiplex, 0x3f)),
         :ok <- display_offset(pid, 0),
         :ok <- start_line(pid, 0),
         :ok <- charge_pump(pid, Map.get(state, :charge_pump, vcc_is_external(state, 0x10, 0x14))),
         :ok <- memory_mode(pid, Map.get(state, :memory_mode, 0x00)),
         :ok <- segment_remap(pid, Map.get(state, :segment_remap, 0x01)),
         :ok <- com_scan_dec!(pid),
         :ok <- com_pins(pid, Map.get(state, :com_pins, 0x12)),
         :ok <- contrast(pid, Map.get(state, :contrast, vcc_is_external(state, 0x9f, 0xcf))),
         :ok <- pre_charge(pid, Map.get(state, :pre_charge, vcc_is_external(state, 0x22, 0xf1))),
         :ok <- vcom_detect(pid, Map.get(state, :vcom_detect, 0x40)),
         :ok <- display_all_on_resume!(pid),
         :ok <- normal_display!(pid),
         do: :ok
  end

  @doc """
  Send a frame to the display.

  Arguments:
    * A map with `:i2c` set to the I2c connection pid, `:width` and `:height in pixels.
    * A bytestring containing the buffer to be displayed.
  """
  def display(%{i2c: pid, width: width, height: height}, buffer) do
    pages = div(height, 8)
    with :ok <- column_address(pid, 0, width - 1),
         :ok <- page_address(pid, 0, pages - 1),
         :ok <- send_buffer(pid, buffer),
         do: :ok
  end

  def contrast(pid, value),                       do: send_commands(pid, [@cmd_set_contrast, value])
  def display_all_on_resume!(pid),                do: send_command(pid, @cmd_display_all_on_resume)
  def display_all_on!(pid),                       do: send_command(pid, @cmd_display_all_on)
  def normal_display!(pid),                       do: send_command(pid, @cmd_normal_display)
  def invert_display!(pid),                       do: send_command(pid, @cmd_invert_display)
  def display_off!(pid),                          do: send_command(pid, @cmd_display_off)
  def display_on!(pid),                           do: send_command(pid, @cmd_display_on)
  def display_offset(pid, value),                 do: send_commands(pid, [@cmd_set_display_offset, value])
  def com_pins(pid, value),                       do: send_commands(pid, [@cmd_set_com_pins, value])
  def vcom_detect(pid, value),                    do: send_commands(pid, [@cmd_set_vcom_detect, value])
  def display_clock_div(pid, value),              do: send_commands(pid, [@cmd_set_display_clock_div, value])
  def pre_charge(pid, value),                     do: send_commands(pid, [@cmd_set_pre_charge, value])
  def multiplex(pid, value),                      do: send_commands(pid, [@cmd_set_multiplex, value])
  #def low_column(pid, value),                     do: send_commands(pid, [@cmd_set_low_column, value])
  #def high_column(pid, value),                    do: send_commands(pid, [@cmd_set_high_column, value])
  def start_line(pid, value),                     do: send_command(pid, @cmd_set_start_line ||| value)
  def memory_mode(pid, value),                    do: send_commands(pid, [@cmd_set_memory_mode, value])
  def column_address(pid, start, fin),            do: send_commands(pid, [@cmd_set_column_address, start, fin])
  def page_address(pid, start, fin),              do: send_commands(pid, [@cmd_set_page_address, start, fin])
  def com_scan_inc!(pid),                         do: send_command(pid, @cmd_com_scan_inc)
  def com_scan_dec!(pid),                         do: send_command(pid, @cmd_com_scan_inc)
  def segment_remap(pid, value),                  do: send_command(pid, @cmd_set_seg_remap ||| value)
  def charge_pump(pid, value),                    do: send_commands(pid, [@cmd_set_charge_pump, value])
  def activate_scroll!(pid),                      do: send_command(pid, @cmd_activate_scroll)
  def deactivate_scroll!(pid),                    do: send_command(pid, @cmd_deactivate_scroll)
  def vertical_scroll_area(pid, value),           do: send_commands(pid, [@cmd_set_vertical_scroll_area, value])
  def right_horizontal_scroll!(pid),              do: send_command(pid, @cmd_right_horizontal_scroll)
  def left_horizontal_scroll!(pid),               do: send_command(pid, @cmd_left_horizontal_scroll)
  def vertical_and_right_horizontal_scroll!(pid), do: send_command(pid, @cmd_vertical_and_right_horizontal_scroll)
  def vertical_and_left_horizontal_scroll!(pid),  do: send_command(pid, @cmd_vertical_and_left_horizontal_scroll)

  defp send_data(pid, << msb::integer-size(8), lsb::integer-size(8) >>), do: I2c.write(pid, <<@data_register, msb, lsb>>)
  defp send_command(pid, byte), do: I2c.write(pid, <<@control_register, byte>>)
  defp send_commands(pid, commands) do
    Enum.reduce(commands, :ok, fn
      _, {:error, _}=error -> error
      byte, :ok            -> send_command(pid, byte)
    end)
  end

  defp send_buffer(pid, << _::integer-size(8), _::integer-size(8) >>=buffer), do: send_data(pid, buffer)
  defp send_buffer(pid, << msb::integer-size(8), lsb::integer-size(8), rest::binary >>) do
    with :ok <- send_data(pid, <<msb, lsb>>),
         :ok <- send_buffer(pid, rest),
         do: :ok
  end

  defp vcc_is_external(%{external_vcc: true}, value, _), do: value
  defp vcc_is_external(_, _, value), do: value
end