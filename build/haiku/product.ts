/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

// What the air/OS (Haiku) build adds to the app's product.json:
//   node build/haiku/product.ts <product.json>
// Code - OSS ships without an extensions gallery; this one uses Open VSX,
// the open registry other Code - OSS builds use.

import * as fs from 'fs';

const file = process.argv[2];
const product = JSON.parse(fs.readFileSync(file, 'utf8'));

product.extensionsGallery = {
	serviceUrl: 'https://open-vsx.org/vscode/gallery',
	itemUrl: 'https://open-vsx.org/vscode/item',
	extensionUrlTemplate: 'https://open-vsx.org/vscode/gallery/{publisher}/{name}/{version}/vspackage',
	resourceUrlTemplate: 'https://open-vsx.org/vscode/unpkg/{publisher}/{name}/{version}/{path}',
	controlUrl: '',
	nlsBaseUrl: '',
	publisherUrl: ''
};
product.linkProtectionTrustedDomains = [...(product.linkProtectionTrustedDomains ?? []), 'https://open-vsx.org'];

fs.writeFileSync(file, JSON.stringify(product, null, '\t') + '\n');
