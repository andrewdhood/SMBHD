/**
 * Created by andrewhood on 1/19/26.
 */

import { LightningElement, api } from 'lwc';

export default class HeroCard extends LightningElement {
    @api hero; // Received from the parent loop

    // Dynamic CSS for the status badge
    get statusClass() {
        let baseClass = 'slds-badge ';
        if (this.hero.effectiveStatus === 'Available') return baseClass + 'slds-theme_success';
        if (this.hero.effectiveStatus === 'On Mission') return baseClass + 'slds-theme_error';
        return baseClass;
    }

    // Logic to disable the de ploy button
    get btnDisabled() {
        // Disable if hero is already on another mission OR if they are injured
        return this.hero.hasConflict || this.hero.effectiveStatus === 'Injured';
    }

    get btnTitle() {
        if (this.hero.hasConflict) return 'Hero is currently deployed elsewhere';
        return 'Deploy to Mission';
    }

    handleDeploy() {
        // Dispatch custom event to parent
        const deployEvent = new CustomEvent('deploy', {
            detail: this.hero.id
        });
        this.dispatchEvent(deployEvent);
    }

    handleRecall() {
        // Dispatch custom event to parent
        const recallEvent = new CustomEvent('recall', {
            detail: this.hero.id
        });
        this.dispatchEvent(recallEvent);
    }
}