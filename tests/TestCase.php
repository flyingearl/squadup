<?php

namespace Tests;

use Illuminate\Foundation\Http\Middleware\PreventRequestForgery;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Laravel\Fortify\Features;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Laravel 13 renamed CSRF middleware from ValidateCsrfToken to
        // PreventRequestForgery. The starter-kit feature tests post to
        // Fortify routes expecting CSRF to be transparent — bypass it at
        // the TestCase level (CSRF itself is covered by framework tests).
        $this->withoutMiddleware(PreventRequestForgery::class);
    }

    protected function skipUnlessFortifyHas(string $feature, ?string $message = null): void
    {
        if (! Features::enabled($feature)) {
            $this->markTestSkipped($message ?? "Fortify feature [{$feature}] is not enabled.");
        }
    }
}
