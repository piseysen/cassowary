// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.domokit.sky.demo;

import android.content.Context;

import org.chromium.mojo.sensors.SensorServiceImpl;
import org.chromium.mojo.system.Core;
import org.chromium.mojo.system.MessagePipeHandle;
import org.chromium.mojom.media.MediaService;
import org.chromium.mojom.sensors.SensorService;
import org.domokit.media.MediaServiceImpl;
import org.domokit.sky.shell.ResourceExtractor;
import org.domokit.sky.shell.ServiceFactory;
import org.domokit.sky.shell.ServiceRegistry;
import org.domokit.sky.shell.SkyApplication;

/**
 * SkyDemo implementation of {@link android.app.Application}
 */
public class SkyDemoApplication extends SkyApplication {
    private static final String[] DEMO_RESOURCES = {
        "cards.skyx",
        "fitness.skyx",
        "game.skyx",
        "interactive_flex.skyx",
        "mine_digger.skyx",
        "stocks.skyx",
    };

    @Override
    protected void onBeforeResourceExtraction(ResourceExtractor extractor) {
        super.onBeforeResourceExtraction(extractor);
        extractor.addResources(DEMO_RESOURCES);
    }

    @Override
    public void onServiceRegistryAvailable(ServiceRegistry registry) {
        super.onServiceRegistryAvailable(registry);

        registry.register(SensorService.MANAGER.getName(), new ServiceFactory() {
            @Override
            public void connectToService(Context context, Core core, MessagePipeHandle pipe) {
                SensorService.MANAGER.bind(new SensorServiceImpl(context), pipe);
            }
        });

        registry.register(MediaService.MANAGER.getName(), new ServiceFactory() {
            @Override
            public void connectToService(Context context, Core core, MessagePipeHandle pipe) {
                MediaService.MANAGER.bind(new MediaServiceImpl(context, core), pipe);
            }
        });
    }
}
