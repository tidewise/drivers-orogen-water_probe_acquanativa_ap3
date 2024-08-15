# frozen_string_literal: true

using_task_library "iodrivers_base"
require "iodrivers_base/orogen_test_helpers"

require_relative "modbus_helpers.rb"

using_task_library "water_probe_acquanativa_ap3"
import_types_from "water_probe_acquanativa_ap3"

describe OroGen.water_probe_acquanativa_ap3.Task do
    include IODriversBase::OroGenTestHelpers

    run_live

    attr_reader :task
    attr_reader :reader
    attr_reader :writer

    attr_reader :probe_measurements_raw
    include ModbusHelpers

    def mock_all_sensor_registers
        registers = {
            "oxygen_concentration" => 0,
            "oxygen_saturation" => 1,
            "temperature" => 2,
            "pH" => 3,
            "conductivity" => 4,
            "salinity" => 5,
            "dissolved_solids" => 6,
            "specific_gravity" => 7,
            "oxidation_reduction_potential" => 8,
            "turbidity" => 9,
            "height" => 10,
            "latitude" => 11,
            "longitude" => 12
        }

        @probe_measurements_raw = [
            756, 85, 2290, 646, 9999, 4739, 8888, 32, 40, 3, 500, 1, 76
        ]
        modbus_set(registers["oxygen_concentration"], @probe_measurements_raw[0])
        modbus_set(registers["oxygen_saturation"], @probe_measurements_raw[1])
        modbus_set(registers["temperature"], @probe_measurements_raw[2])
        modbus_set(registers["pH"], @probe_measurements_raw[3])
        modbus_set(registers["conductivity"], @probe_measurements_raw[4])
        modbus_set(registers["salinity"], @probe_measurements_raw[5])
        modbus_set(registers["dissolved_solids"], @probe_measurements_raw[6])
        modbus_set(registers["specific_gravity"], @probe_measurements_raw[7])
        modbus_set(registers["oxidation_reduction_potential"], @probe_measurements_raw[8])
        modbus_set(registers["turbidity"], @probe_measurements_raw[9])
        modbus_set(registers["height"], @probe_measurements_raw[10])
        modbus_set(registers["latitude"], @probe_measurements_raw[11])
        modbus_set(registers["longitude"], @probe_measurements_raw[12])
    end

    before do
        @task, @reader, @writer = iodrivers_base_prepare(
            OroGen.water_probe_acquanativa_ap3.Task
                . deployed_as("water_probe_acquanativa_ap3_test")
        )

        modbus_helpers_setup(@task, @reader, @writer)
    end

    describe "test component configure" do
        it "cheks for device address setting obligatoriness" do
            expect_execution.scheduler(true).to { fail_to_start task }
        end
    end

    describe "getting new measurements" do
        before do
            task.properties.device_address = 57
            task.properties.io_read_timeout = Time.at(1)
            task.properties.max_consecutive_timeouts = 1
            modbus_configure_and_start
        end

        it "sets the sample timestamp's to the reception time" do
            read_request_time = Time.now
            sample = modbus_expect_execution(@writer, @reader) do
                mock_all_sensor_registers
            end.to do
                have_one_new_sample task.probe_measurements_port
            end
            now = Time.now
            dt = now - read_request_time
            assert_in_delta(now, sample.time, dt)
        end

        it "reports all measurements" do
            measurements = modbus_expect_execution(@writer, @reader) do
                mock_all_sensor_registers
            end.to do
                have_one_new_sample task.probe_measurements_port
            end

            assert_in_delta(756 / 100.0 * 1e-6 / 1e-3, measurements.oxygen_concentration)
            assert_in_delta(85 * 1e-4, measurements.oxygen_saturation)
            assert_in_delta(22.9 + 273.15, measurements.temperature.kelvin)
            assert_in_delta(646 / 100.0, measurements.pH)
            assert_in_delta(9999, measurements.raw_conductivity)
            assert_in_delta(65_300 * 1e-6 / 1e-2, measurements.conductivity, 1e-4)
            assert_in_delta(47.39 * 1e-3, measurements.salinity)
            assert_in_delta(8888, measurements.raw_dissolved_solids)
            assert_in_delta(42_445 / 1e6, measurements.dissolved_solids)
            assert_in_delta(32 / 100.0, measurements.specific_gravity)
            assert_in_delta(40 * 1e-3, measurements.oxidation_reduction_potential)
            assert_in_delta(3, measurements.turbidity)
            assert_in_delta(500, measurements.height)
            assert_in_delta(1 / 100.0, measurements.latitude)
            assert_in_delta(76 / 100.0, measurements.longitude)
        end

        it "does not output anything if there are no measurements " do
            modbus_expect_execution(@writer, @reader) do
                have_no_new_sample task.probe_measurements_port, at_least_during: 0.5
            end
        end

        it "allows for a configured amount of retries if the device does not answer" do
            expect_execution.timeout(10).to { not_emit task.timeout_event, within: 5 }
            @reader.clear
            modbus_expect_execution(@writer, @reader) do
                mock_all_sensor_registers
            end.to do
                have_one_new_sample task.probe_measurements_port
            end
        end

        it "resets the number of allowed timeouts after a successful read" do
            expect_execution.timeout(10).to { not_emit task.timeout_event, within: 5 }
            @reader.clear
            modbus_expect_execution(@writer, @reader) do
                mock_all_sensor_registers
            end.to do
                have_one_new_sample task.probe_measurements_port
            end
            expect_execution.timeout(10).to { not_emit task.timeout_event, within: 5 }
            @reader.clear
        end
    end

    it "times out if no answer comes after the configured amount of tries" do
        task.properties.device_address = 57
        task.properties.io_read_timeout = Time.at(1)
        task.properties.max_consecutive_timeouts = 1
        modbus_configure_and_start

        modbus_expect_execution(@writer, @reader) do
            mock_all_sensor_registers
        end.to do
            have_one_new_sample task.probe_measurements_port
        end
        tic = Time.now

        expect_execution.timeout(10).to { emit task.timeout_event }
        now = Time.now
        # There is variability in how long the first modbus_expect_execution takes to
        # finish due to the time it takes dealing with the many modbus replies/requests.
        # Because of that, tic is behind the actual timeout timer start by ~0.250ms
        # (without cpu restrictions).
        #
        # We account for that variability by adding a threshold of 0.5s
        # in the time it takes to emit the timeout event. The expected time should be:
        #
        # 3s default period, 0s read timeout: 0 consecutive timeouts
        # 4s default period, 1s read timeout: 1 consecutive timeouts
        # 6s default period, 0s read timeout: 1 consecutive timeouts
        # 7s default period, 1s read timeout: 2 consecutive timeouts => trigger timeout
        assert_includes (6.5..7.5), (now - tic)
    end
end
