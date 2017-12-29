/*
 * Copyright (C) 2008 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#define LOG_TAG "Sensors"

#include <hardware/sensors.h>
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <dirent.h>
#include <math.h>
#include <poll.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>
#include <stdlib.h>

#include <linux/input.h>


#include <utils/Atomic.h>
#include <utils/Log.h>

#include "sensors.h"

#include "LightSensor.h"


/*****************************************************************************/

#define DELAY_OUT_TIME 0x7FFFFFFF

#define LIGHT_SENSOR_POLLTIME    2000000000



#define SENSORS_LIGHT_HANDLE            ID_L

#define MAX_SENSOR_NUM                  1
#define UNSET_FIELD -1
#define SENSOR_FIFO_SIZE	(2048 *2 /3)

/*****************************************************************************/

/* Support SENSORS Module */
static const struct sensor_t sSensorSupportList[] = {
	{
		.name =					"stk3310 light sensor",
		.vendor =				"Nexell",
		.version =				1,
		.handle =				SENSORS_LIGHT_HANDLE,
		.type =					SENSOR_TYPE_LIGHT,
		.maxRange =				10240.0f,
		.resolution =			1.0f,
		.power =				0.5f,
		.minDelay =				5000,
		.fifoReservedEventCount = 0,
		.fifoMaxEventCount =	SENSOR_FIFO_SIZE,
		.stringType =			SENSOR_STRING_TYPE_LIGHT,
		.requiredPermission = 0,
		/* Forced mode, can be long: 10s */
		.maxDelay =				10000000,
		.flags =				SENSOR_FLAG_ON_CHANGE_MODE,
		.reserved =				{ 0 }
	},
};

/* Current SENSORS Module */
static struct sensor_t sSensorList[MAX_SENSOR_NUM] = {};
static int sSensorListNum = 0;

static int open_sensors(const struct hw_module_t* module, const char* id,
						struct hw_device_t** device);


static int sensors_detect_devices(const struct sensor_t* slist, int ssize,
                                struct sensor_t* clist, int csize)
{
	const char *dirname = "/dev/input";
	char devname[PATH_MAX];
	char *filename;
	int fd = -1;
	DIR *dir;
	struct dirent *de;
	int count = 0;
	int idx = 0;

	dir = opendir(dirname);
	if(dir == NULL)
    	return 0;

	strcpy(devname, dirname);
	filename = devname + strlen(devname);
	*filename++ = '/';

	while((de = readdir(dir))) {
		if(de->d_name[0] == '.' &&
			(de->d_name[1] == '\0' ||
			(de->d_name[1] == '.' && de->d_name[2] == '\0')))
			continue;

		strcpy(filename, de->d_name);

		fd = open(devname, O_RDONLY);
		if (fd>=0) {
			char name[80];
			if (ioctl(fd, EVIOCGNAME(sizeof(name) - 1), &name) < 1) {
				name[0] = '\0';
			}
			for (idx = 0; idx < ssize; idx++) {
				if (!strcmp(name, slist[idx].stringType)) {
					memcpy(&clist[count], &slist[idx], sizeof(struct sensor_t));
					count ++;
				break;
				}
			}
		}
		close(fd);
		fd = -1;

		if (count >= csize)
			break;
	}
	closedir(dir);
	return count;
}

static int sensors__get_sensors_list(struct sensors_module_t* module,
									struct sensor_t const** list)
{
	*list = sSensorList;
	return sSensorListNum;
}

static struct hw_module_methods_t sensors_module_methods = {
	.open=open_sensors
};

struct sensors_module_t HAL_MODULE_INFO_SYM = {
	.common = {
		.tag = HARDWARE_MODULE_TAG,
		.version_major = 1,
		.version_minor = 0,
		.id = SENSORS_HARDWARE_MODULE_ID,
		.name = "NXP4330 sensor module",
		.author = "Nexell.co.Ltd",
		.methods = &sensors_module_methods,
		.dso = 0,
		.reserved = {},
	},
	.get_sensors_list = sensors__get_sensors_list,
};

struct sensors_poll_context_t {
	struct sensors_poll_device_t device; /* must be first */
	sensors_poll_context_t();
	~sensors_poll_context_t();
	int activate(int handle, int enabled);
	int setDelay(int handle, int64_t ns);
	int pollEvents(sensors_event_t* data, int count);

private:
	enum {
		light,
		numSensorDrivers,   /* max sensor num */
		numFds,     /* max fd num */
	};

	static const size_t wake = numFds - 1;
	static const char WAKE_MESSAGE = 'W';
	struct pollfd mPollFds[numFds];
	int mWritePipeFd;
	SensorBase* mSensors[numSensorDrivers];

	/* For keeping track of usage (only count from system) */
	int real_activate(int handle, int enabled);

	int handleToDriver(int handle) const {
		switch (handle) {
			case SENSORS_LIGHT_HANDLE:
				return light;
		}
		return -EINVAL;
	}
};

/*****************************************************************************/

sensors_poll_context_t::sensors_poll_context_t()
{
	int index = 0;
	struct sensor_t* ss = NULL;

	/* clear sensors */
	for (index = 0; index < numSensorDrivers; index++) {
		mSensors[index] = NULL;
	}

	/* clear mPollFds */
	for (index = 0; index < numFds; index++) {
		memset(&(mPollFds[index]), 0, sizeof(pollfd));
		mPollFds[index].fd = -1;
	}

	/* detect sensors */
	if (sSensorListNum <= 0) {
		sSensorListNum = sensors_detect_devices(sSensorSupportList,
									MAX_SENSOR_NUM,
									sSensorList, ARRAY_SIZE(sSensorList));
	}

	/* create sensors */
	for (index = 0; index < sSensorListNum; index++) {
		ss = &sSensorList[index];

		switch(ss->type) {
			case SENSOR_TYPE_LIGHT:
				if( mSensors[light] == NULL) {
					mSensors[light] =
						new LightSensor(const_cast<char *>(ss->stringType),
										ss->resolution, ss->minDelay);
					mPollFds[light].fd = mSensors[light]->getFd();
					mPollFds[light].events = POLLIN;
					mPollFds[light].revents = 0;
				}
			break;
		}
	}

	int wakeFds[2];
	int result = pipe(wakeFds);
	ALOGE_IF(result<0, "error creating wake pipe (%s)", strerror(errno));
	fcntl(wakeFds[0], F_SETFL, O_NONBLOCK);
	fcntl(wakeFds[1], F_SETFL, O_NONBLOCK);
	mWritePipeFd = wakeFds[1];

	mPollFds[wake].fd = wakeFds[0];
	mPollFds[wake].events = POLLIN;
	mPollFds[wake].revents = 0;

}

sensors_poll_context_t::~sensors_poll_context_t()
{
	for (int i=0 ; i<numSensorDrivers ; i++) {
		if (mSensors[i] != NULL) {
			delete mSensors[i];
		}
	}
	close(mPollFds[wake].fd);
	close(mWritePipeFd);
}

int sensors_poll_context_t::activate(int handle, int enabled)
{
	return real_activate(handle, enabled);
}

int sensors_poll_context_t::real_activate(int handle, int enabled)
{
	int index = handleToDriver(handle);
	if (index < 0) return index;
	int err =  mSensors[index]->enable(handle, enabled);
	if (enabled && !err) {
		const char wakeMessage(WAKE_MESSAGE);
		int result = write(mWritePipeFd, &wakeMessage, 1);
		ALOGE_IF(result<0, "error sending wake message (%s)", strerror(errno));
	}
	return err;
}

int sensors_poll_context_t::setDelay(int handle, int64_t ns)
{
	int index = handleToDriver(handle);
	if (index < 0) return index;
	return mSensors[index]->setDelay(handle, ns);
}

int sensors_poll_context_t::pollEvents(sensors_event_t* data, int count)
{
	int nbEvents = 0;
	int n = 0;

	do {
        /* see if we have some leftover from the last poll() */
		for (int i=0 ; count && i<numSensorDrivers ; i++) {
			SensorBase* const sensor(mSensors[i]);
			if (sensor == NULL) {
				continue;
			}
			if ((mPollFds[i].revents & POLLIN) ||
					(sensor->hasPendingEvents())) {
				int nb = sensor->readEvents(data, count);
				if (nb < count) {
					/*  no more data for this sensor */
					mPollFds[i].revents = 0;
				}
				count -= nb;
				nbEvents += nb;
				data += nb;
			}
		}

		if (count) {
		/*  we still have some room, so try to see if we can get
			some events immediately or just wait if we don't have
			anything to return */
			do {
				n = poll(mPollFds, numFds, nbEvents ? 0 : -1);
			} while (n < 0 && errno == EINTR);
			if (n<0) {
				ALOGE("poll() failed (%s)", strerror(errno));
				return -errno;
			}
			if (mPollFds[wake].revents & POLLIN) {
				char msg;
				int result = read(mPollFds[wake].fd, &msg, 1);
				ALOGE_IF(result<0, "error reading from wake pipe (%s)",
						strerror(errno));
				ALOGE_IF(msg != WAKE_MESSAGE,
						"unknown message on wake queue (0x%02x)", int(msg));
				mPollFds[wake].revents = 0;
			}
		}
		/* if we have events and space, go read them */
	} while (n && count);

	return nbEvents;
}

/*****************************************************************************/

static int poll__close(struct hw_device_t *dev)
{
	sensors_poll_context_t *ctx = (sensors_poll_context_t *)dev;
	if (ctx) {
		delete ctx;
	}
	return 0;
}

static int poll__activate(struct sensors_poll_device_t *dev,
		int handle, int enabled) {
	sensors_poll_context_t *ctx = (sensors_poll_context_t *)dev;
	return ctx->activate(handle, enabled);
}

static int poll__setDelay(struct sensors_poll_device_t *dev,
		int handle, int64_t ns) {
	sensors_poll_context_t *ctx = (sensors_poll_context_t *)dev;
	return ctx->setDelay(handle, ns);
}

static int poll__poll(struct sensors_poll_device_t *dev,
		sensors_event_t* data, int count) {
	sensors_poll_context_t *ctx = (sensors_poll_context_t *)dev;
	return ctx->pollEvents(data, count);
}

/*****************************************************************************/
/* Open a new instance of a sensor device using name */
/*****************************************************************************/
static int open_sensors(const struct hw_module_t* module, const char* id,
						struct hw_device_t** device)
{
	int status = -EINVAL;
	sensors_poll_context_t *dev = new sensors_poll_context_t();

	memset(&dev->device, 0, sizeof(sensors_poll_device_t));

	dev->device.common.tag 		= HARDWARE_DEVICE_TAG;
	dev->device.common.version	= 0;
	dev->device.common.module	= const_cast<hw_module_t*>(module);
	dev->device.common.close	= poll__close;
	dev->device.activate		= poll__activate;
	dev->device.setDelay		= poll__setDelay;
	dev->device.poll			= poll__poll;

	*device = &dev->device.common;
	status = 0;

	return status;
}

