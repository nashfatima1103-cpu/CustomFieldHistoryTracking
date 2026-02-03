import { LightningElement, api, wire, track } from 'lwc';
import getAuditRecords from '@salesforce/apex/AuditTableController.getAuditRecords';

const COLUMNS = [
    {
        label: '',
        type: 'button',
        fixedWidth: 90,
        typeAttributes: {
            label: 'Expand',
            name: 'expand',
            variant: 'base'
        }
    },
    {
        label: 'Field Name',
        fieldName: 'Field_Name__c',
        type: 'text'
    },
    {
        label: 'Old Value',
        fieldName: 'Old_Value__c',
        type: 'text',
    },
    {
        label: 'Old Value (Lookup ID)',
        fieldName: 'Old_Value_Lookup_ID__c',
        type: 'text'
    },
    {
        label: 'New Value',
        fieldName: 'New_Value__c',
        type: 'text',
    },
    {
        label: 'New Value (Lookup ID)',
        fieldName: 'New_Value_Lookup_ID__c',
        type: 'text'
    },
    {
        label: 'Modified By',
        fieldName: 'ModifiedByName',
        type: 'text'
    },
    {
        label: 'Modified Date',
        fieldName: 'Modified_Date__c',
        type: 'date',
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
    error;

    @track showExpand = false;
    @track selectedRow;

    @wire(getAuditRecords, { recordId: '$recordId' })
    wiredAudits({ data, error }) {
        if (data) {
            this.data = data.map(row => ({
                ...row,
                ModifiedByName: row.Modified_By__r?.Name
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.data = [];
        }
    }

    handleRowAction(event) {
        if (event.detail.action.name === 'expand') {
            this.selectedRow = event.detail.row;
            this.showExpand = true;
        }
    }

    closeExpand() {
        this.showExpand = false;
        this.selectedRow = null;
    }
}
