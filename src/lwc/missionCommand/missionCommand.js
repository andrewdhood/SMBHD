/**
 * Created by andrewhood on 1/19/26.
 */

import { LightningElement, api, wire, track } from 'lwc';
import getHeroesForMission from '@salesforce/apex/MissionCommandController.getHeroesForMission';
import getPowerOptions from '@salesforce/apex/MissionCommandController.getPowerOptions';
import deployHeroToMission from '@salesforce/apex/MissionCommandController.deployHeroToMission';
import recallHeroFromMission from '@salesforce/apex/MissionCommandController.recallHeroFromMission';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class MissionCommand extends LightningElement {
    @api recordId; // Mission ID from the record page
    @track selectedPower = 'All';
    @track heroes;
    @track error;

    wiredHeroesResult; // Hold this for refreshApex

    // Fetch Power Picklist Values
    @wire(getPowerOptions)
    wiredOptions({ error, data }) {
        if (data) {
            console.log('Power Options received from Apex:', JSON.stringify(data));

            // Format check: Combobox requires { label: 'Text', value: 'API_Value' }
            this.powerOptions = data.map(opt => {
                return { label: opt.label, value: opt.value };
            });

            console.log('Formatted Options for Combobox:', JSON.stringify(this.powerOptions));
        } else if (error) {
            console.error('Error fetching Power Options:', error);
        }
    }

    // Fetch Heroes based on Mission and Filter
    @wire(getHeroesForMission, { missionId: '$recordId', powerFilter: '$selectedPower' })
    wiredHeroes(result) {
        this.wiredHeroesResult = result;
        if (result.data) {
            this.heroes = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = 'Error loading heroes';
            this.heroes = undefined;
        }
    }

    get deployedCount() {
        return this.heroes ? this.heroes.filter(h => h.isDeployedHere).length : 0;
    }

    get deploymentCountClass() {
        return this.deployedCount >= 3 ? 'slds-text-color_error slds-text-heading_small' : 'slds-text-heading_small';
    }

    handlePowerChange(event) {
        console.log('User selected new power:', event.detail.value);
        this.selectedPower = event.detail.value;
    }

    // Action: Deploy
    handleDeploy(event) {
        const heroId = event.detail;
        deployHeroToMission({ heroId: heroId, missionId: this.recordId })
            .then(() => {
                this.showToast('Success', 'Hero Deployed!', 'success');
                return refreshApex(this.wiredHeroesResult);
            })
            .catch(error => {
                // Use the helper to get the clean message
                const cleanMessage = this.reduceErrors(error);
                this.showToast('Deployment Denied', cleanMessage, 'error');
            });
    }

    // Action: Recall
    handleRecall(event) {
        const heroId = event.detail; // Received from the heroCard child component

        recallHeroFromMission({ heroId: heroId, missionId: this.recordId })
            .then(() => {
                this.showToast('Success', 'Hero recalled to base.', 'success');
                // CRITICAL: This pulls the fresh 'Available' status and new count from the server
                return refreshApex(this.wiredHeroesResult);
            })
            .catch(error => {
                this.showToast('Error', 'Recall failed: ' + error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // Helper function to extract the clean message
    reduceErrors(errors) {
        if (!Array.isArray(errors)) {
            errors = [errors];
        }

        return errors
            .map((error) => {
                if (error.body && Array.isArray(error.body)) {
                    return error.body.map((e) => e.message);
                } else if (error.body && typeof error.body.message === 'string') {
                    return error.body.message; // trying to catch AuraHandledExceptions
                } else if (error.message) {
                    return error.message;
                }
                return error.statusText;
            })
            .reduce((prev, curr) => prev.concat(curr), [])
            .filter((message) => !!message)
            .join(', ');
    }
}