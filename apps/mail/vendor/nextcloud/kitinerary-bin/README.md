<!--
  - SPDX-FileCopyrightText: 2019 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->

# kitinerary-bin

[![REUSE status](https://api.reuse.software/badge/github.com/nextcloud-libraries/kitinerary-bin)](https://api.reuse.software/info/github.com/nextcloud-libraries/kitinerary-bin)

Binary executable adapter for the [kitinerary extractor package](https://packagist.org/packages/nextcloud/kitinerary). This package provides an adapter that invokes a shipped [kitinerary-extractor](https://github.com/KDE/itinerary) executable on x86_64 Linux systems.

The statically linked binary is created [from source](https://invent.kde.org/vkrause/kitinerary-static-build).

## Installation

```sh
composer require nextcloud/kitinerary nextcloud/kitinerary-bin
```

## Usage

```php
use Nextcloud\KItinerary\ItineraryExtractor;
use Nextcloud\KItinerary\Bin\BinaryAdapter;
use Nextcloud\KItinerary\Exception\KItineraryRuntimeException;

$adapter = new BinaryAdapter();
if (!$adapter->isAvailable()) {
    // ...
}
$extractor = new Extractor($adapter);

try {
    $itinerary = $extractor->extractFromString('...');
} catch (KItineraryRuntimeException $e) {
    // ...
}
```
