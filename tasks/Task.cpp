/* Generated from orogen/lib/orogen/templates/tasks/Task.cpp */

#include "Task.hpp"
#include <iodrivers_base/ConfigureGuard.hpp>
#include <memory>
#include <modbus/RTU.hpp>

using namespace water_probe_acquanativa_ap3;

Task::Task(std::string const& name)
    : TaskBase(name)
    , m_driver(nullptr)
{
}

Task::~Task()
{
}



/// The following lines are template definitions for the various state machine
// hooks defined by Orocos::RTT. See Task.hpp for more detailed
// documentation about them.

bool Task::configureHook()
{
    const int device_modbus_address = _device_address.get();
    if(device_modbus_address < 0) {
        return false;
    }
    std::unique_ptr<Driver> driver( new Driver(device_modbus_address));

    iodrivers_base::ConfigureGuard guard(this);

    const std::string device_port = _io_port.get();
    if(not device_port.empty())
        driver->openURI(device_port);

    setDriver(driver.get());
    if (! TaskBase::configureHook())
        return false;

    m_driver = std::move(driver);
    guard.commit();

    return true;
}

bool Task::startHook()
{
    if (! TaskBase::startHook())
        return false;
    m_timeouts = 0;
    return true;
}
void Task::updateHook()
{
    TaskBase::updateHook();

    try {
        _probe_measurements.write(m_driver->getMeasurements());
        m_timeouts = 0;
    }
    catch (modbus::RTU::TooSmall&) {
        m_timeouts++;

        if (m_timeouts > _max_consecutive_timeouts.get()) {
            exception(TIMEOUT);
            return;
        }
    }
}
void Task::errorHook()
{
    TaskBase::errorHook();
}
void Task::stopHook()
{
    TaskBase::stopHook();
}
void Task::cleanupHook()
{
    TaskBase::cleanupHook();
}

void
Task::processIO()
{
    // Because that Modbus is a master/slave protocol, this method is never called in the
    // iodrivers_base::Task. So it is left empty.
}