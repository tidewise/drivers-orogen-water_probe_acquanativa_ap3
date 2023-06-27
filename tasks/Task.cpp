/* Generated from orogen/lib/orogen/templates/tasks/Task.cpp */

#include "Task.hpp"
#include <iodrivers_base/ConfigureGuard.hpp>
#include <memory>

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
    if(!device_port.empty()){
        driver->openURI(device_port);
    }
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
    return true;
}
void Task::updateHook()
{
    TaskBase::updateHook();

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
    water_probe_acquanativa_ap3::ProbeMeasurements sample(
        m_driver->getMeasurements()
    );
    _data.write(sample);
}