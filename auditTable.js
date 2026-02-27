import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getAuditRecords from '@salesforce/apex/AuditTableController.getAuditRecords';

const COLUMNS = [
    {
        label: '',
        type: 'button',
        initialWidth: 100,
        typeAttributes: {
            label: 'Expand',
            name: 'expand',
            variant: 'base'
        }
    },
    { label: 'Field Name', fieldName: 'Field_Name__c', type: 'text', initialWidth: 180 },
    { label: 'Old Value', fieldName: 'Old_Value__c', type: 'text', initialWidth: 250 },
    { label: 'Old Value (Lookup ID)', fieldName: 'Old_Value_Lookup_ID__c', type: 'text', initialWidth: 200 },
    { label: 'New Value', fieldName: 'New_Value__c', type: 'text', initialWidth: 250 },
    { label: 'New Value (Lookup ID)', fieldName: 'New_Value_Lookup_ID__c', type: 'text', initialWidth: 200 },
    { label: 'Modified By', fieldName: 'ModifiedByName', type: 'text', initialWidth: 180 },
    {
        label: 'Modified Date',
        fieldName: 'Modified_Date__c',
        type: 'date',
        initialWidth: 200,
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    }
];

export default class AuditTable extends LightningElement {
    @api recordId;

    columns = COLUMNS;
    data = [];
    wiredResult;

    @track showExpand = false;
    @track selectedRow;
    @track showFullModal = false;
    @track isLoading = false;

    get recordCount() {
        return this.data ? this.data.length : 0;
    }

    @wire(getAuditRecords, { recordId: '$recordId' })
    wiredAudits(result) {
        this.wiredResult = result;
        if (result.data) {
            this.data = result.data.map(row => ({
                ...row,
                ModifiedByName: row.Modified_By__r?.Name
            }));
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        await refreshApex(this.wiredResult);
        this.isLoading = false;
    }

    handleRowAction(event) {
        if (event.detail.action.name === 'expand') {
            this.selectedRow = event.detail.row;
            this.showExpand = true;
        }
    }

    openFullModal() {
        this.showFullModal = true;
    }

    closeFullModal() {
        this.showFullModal = false;
    }

    closeExpand() {
        this.showExpand = false;
        this.selectedRow = null;
    }
}
